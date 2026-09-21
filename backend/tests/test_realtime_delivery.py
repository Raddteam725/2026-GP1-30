"""The shared real-time contract, both directions:
commit -> durable notification record -> immediate push attempt (never
waiting for the reconciliation job) -> receipts make retries exact.

Guardian create / cancel / resolve toward Volunteers, Volunteer stages toward
the Guardian, the session-aware registration lifecycle, reconciliation and
the maintenance boundary. FCM itself is faked (app.delivery's send_each);
real delivery is only provable on a real device.
"""
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta, timezone
from unittest.mock import Mock
import pytest
from fastapi.testclient import TestClient
from firebase_admin import messaging
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import volunteer_alerts, delivery, sessions, push, local_jobs, main as main_module
from app.main import app
from app.firebase import identity
from app.volunteer import VolunteerDevice
from app.cases import CaseService
from app.case_models import CaseCreate
from test_volunteer import db, vol, case
from test_volunteer_alert_delivery import sends, device

def receipts(db, prefix):
    return {p: d for p, d in db.data.items() if p.startswith(prefix) and '/deliveries/' in p}

def volunteer_notes(db, uid, case_id):
    return {p.split('/')[-1]: d for p, d in db.data.items()
            if p.startswith(f'users/{uid}/volunteer_notifications/') and '/deliveries/' not in p and d.get('case_id') == case_id}

# --- Guardian -> Volunteer -------------------------------------------------

def test_create_writes_durable_volunteer_record_and_attempts_push_in_the_same_call(db, sends):
    device('one')
    guardian, identifier = case()  # returns only after CaseService.create returned
    notes = volunteer_notes(db, 'one', identifier)
    assert notes[identifier + '-new']['kind'] == 'new_case'
    assert sends.call_count == 1
    message = sends.call_args.args[0]
    assert message.data == {'role': 'volunteer', 'case_id': identifier, 'event_id': 'test-event', 'kind': 'general', 'status': 'report_received'}
    (receipt,) = receipts(db, f'users/one/volunteer_notifications/{identifier}-new').values()
    assert receipt['sent_at']  # accepted by FCM in the request itself, not by a later job

@pytest.mark.parametrize('action, outcome', [('cancel', 'cancelled'), ('resolve', 'resolved')])
def test_guardian_closure_notifies_exactly_the_volunteers_who_were_told(db, sends, action, outcome):
    device('one')          # alerted (holds the `-new` record) but never joined
    device('two')          # alerted and joined
    db.set(db.collection('users').document('three'), {'role': 'volunteer', 'active': True,
        'full_name': 'Volunteer three', 'volunteer_id': 'VOL-three', 'email': 't@example.test', 'phone': '+966500000003'})
    guardian, identifier = case()
    vol('two').start_search(identifier)
    device('three')        # registers only AFTER the case existed: never alerted about it
    for note in [p for p in list(db.data) if p.startswith('users/three/volunteer_notifications/')]:
        db.data.pop(note)  # registration re-dispatch materialised it; the model under test is "was told"
    sends.reset_mock()
    result = getattr(CaseService(guardian), action)(identifier)
    assert result['status'] == outcome
    for uid in ('one', 'two'):
        record = volunteer_notes(db, uid, identifier)[identifier + '-' + outcome]
        assert record['kind'] == 'case_closed' and record['status'] == outcome and record['read_at'] is None
    assert identifier + '-' + outcome not in volunteer_notes(db, 'three', identifier)
    tokens = sorted(call.args[0].token for call in sends.call_args_list)
    assert tokens == ['device-one', 'device-two']
    assert {call.args[0].data['kind'] for call in sends.call_args_list} == {'case_closed'}
    assert {call.args[0].data['status'] for call in sends.call_args_list} == {outcome}
    assert 'Missing Person' not in str(sends.call_args_list)
    # Idempotent: a reconciliation run re-sends nothing already accepted.
    volunteer_alerts.dispatch(db, identifier)
    assert sends.call_count == 2

def test_closure_record_exists_even_when_the_volunteer_has_no_reachable_device(db, sends):
    device('one')
    guardian, identifier = case()
    vol().start_search(identifier)
    for path in [p for p in list(db.data) if '/fcm_registrations/' in p]:
        db.data.pop(path)  # device gone (logged out / token removed)
    sends.reset_mock()
    CaseService(guardian).cancel(identifier)
    assert volunteer_notes(db, 'one', identifier)[identifier + '-cancelled']['kind'] == 'case_closed'
    assert sends.call_count == 0

def test_push_failure_never_undoes_the_committed_closure_and_stays_retryable(db, sends):
    device('one')
    guardian, identifier = case()
    vol().start_search(identifier)
    sends.side_effect = OSError('offline')
    resolved = CaseService(guardian).resolve(identifier)
    assert resolved['status'] == 'resolved'
    assert db.data['cases/' + identifier]['status'] == 'resolved'
    assert identifier + '-resolved' in volunteer_notes(db, 'one', identifier)
    assert CaseService(guardian).list_notifications()[0]['status'] == 'resolved'
    assert not receipts(db, f'users/one/volunteer_notifications/{identifier}-resolved')
    sends.side_effect = None
    volunteer_alerts.dispatch(db, identifier)  # what the reconciliation job does
    (receipt,) = receipts(db, f'users/one/volunteer_notifications/{identifier}-resolved').values()
    assert receipt['sent_at']

def test_whole_batch_failure_releases_leases_for_retry(db, sends, monkeypatch):
    device('one')
    guardian, identifier = case()
    sends.reset_mock()
    def exploding(messages, app=None):
        raise ConnectionError('FCM unreachable')
    monkeypatch.setattr(delivery.messaging, 'send_each', exploding)
    CaseService(guardian).cancel(identifier)
    assert db.data['cases/' + identifier]['status'] == 'cancelled'
    assert not receipts(db, f'users/one/volunteer_notifications/{identifier}-cancelled')

def test_reunited_does_not_produce_a_closure_notice(db, sends):
    device('one')
    guardian, identifier = case()
    vol().start_search(identifier)
    db.data['cases/' + identifier].update(status='reunited', closed_at=datetime.now(timezone.utc), handed_over_by='one')
    sends.reset_mock()
    volunteer_alerts.dispatch(db, identifier)
    assert sends.call_count == 0
    assert identifier + '-reunited' not in volunteer_notes(db, 'one', identifier)

def test_cancel_and_resolve_remain_authenticated_and_owner_scoped(db, sends):
    guardian, identifier = case()
    with TestClient(app) as client:
        assert client.post(f'/v1/cases/{identifier}/cancel').status_code == 401
        assert client.post(f'/v1/cases/{identifier}/resolve').status_code == 401
    from test_cases import guardian_with_individual
    other, _ = guardian_with_individual('intruder')
    app.dependency_overrides[identity] = lambda: {'uid': 'intruder', 'email': 'i@example.test'}
    with TestClient(app) as client:
        assert client.post(f'/v1/cases/{identifier}/cancel').status_code == 404
        assert client.post(f'/v1/cases/{identifier}/resolve').status_code == 404
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        assert client.post(f'/v1/cases/{identifier}/cancel').status_code == 403  # a Volunteer is not a Guardian
    assert db.data['cases/' + identifier]['status'] == 'report_received'

# --- Volunteer -> Guardian -------------------------------------------------

def guardian_sender(monkeypatch, outcomes):
    sender = Mock(side_effect=lambda messages, app=None: messaging.BatchResponse(
        [outcomes.get(m.token, messaging.SendResponse({'name': 'id'}, None)) for m in messages]))
    monkeypatch.setattr(delivery.messaging, 'send_each', sender)
    return sender

def test_volunteer_stage_change_pushes_the_guardian_immediately_with_a_receipt(db, sends, monkeypatch):
    guardian, identifier = case()
    guardian.register_fcm_token('guardian-device', 'ar')
    sender = guardian_sender(monkeypatch, {})
    vol().start_search(identifier)
    (messages,) = [call.args[0] for call in sender.call_args_list]
    assert [m.token for m in messages] == ['guardian-device']
    assert messages[0].data == {'role': 'guardian', 'kind': 'status_update', 'status': 'search_in_progress', 'case_id': identifier, 'event_id': 'test-event'}
    assert messages[0].notification.title == 'راد'
    (receipt,) = receipts(db, f'users/guardian/notifications/{identifier}-search_in_progress').values()
    assert receipt['sent_at']

def test_guardian_push_failure_is_reconciled_by_retry_recent(db, sends, monkeypatch):
    guardian, identifier = case()
    guardian.register_fcm_token('guardian-device')
    failing = guardian_sender(monkeypatch, {'guardian-device': messaging.SendResponse(None, messaging.QuotaExceededError('busy'))})
    vol().start_search(identifier)
    assert failing.call_count == 1
    assert not receipts(db, f'users/guardian/notifications/{identifier}-search_in_progress')
    working = guardian_sender(monkeypatch, {})
    push.retry_recent(db)
    (receipt,) = receipts(db, f'users/guardian/notifications/{identifier}-search_in_progress').values()
    assert receipt['sent_at']
    # (The creation notification, written before this device registered, is
    # reconciled by the same run -- every recent record without a receipt is.)
    assert {m.data['status'] for call in working.call_args_list for m in call.args[0]} == {'report_received', 'search_in_progress'}
    attempts = working.call_count
    push.retry_recent(db)  # accepted once: never sent twice
    assert working.call_count == attempts

# --- FCM registration lifecycle (shared app.sessions) --------------------

def test_registration_is_stamped_from_the_verified_token(db, sends):
    exp = (datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()
    vol('one', exp=exp, auth_time=exp - 3600).register_device(VolunteerDevice(token='device-one'))
    (registration,) = [d for p, d in db.data.items() if p.startswith('users/one/fcm_registrations/')]
    assert registration['session_expires_at'] == exp
    assert registration['auth_time'] == exp - 3600

def expire_registrations(db):
    for path, data in db.data.items():
        if '/fcm_registrations/' in path:
            data['session_expires_at'] = 0

def test_expired_token_window_with_a_live_firebase_session_keeps_delivering(db, sends, monkeypatch):
    device('one')
    guardian, identifier = case()
    expire_registrations(db)
    checks = []
    monkeypatch.setattr(sessions, 'verify_session', lambda uid, registration: checks.append(uid) or 'valid')
    sends.reset_mock()
    CaseService(guardian).cancel(identifier)
    assert sends.call_count == 1 and checks == ['one']
    (registration,) = [d for p, d in db.data.items() if p.startswith('users/one/fcm_registrations/')]
    window = sessions.SESSION_WINDOW.total_seconds()
    assert datetime.now(timezone.utc).timestamp() + window - 5 < registration['session_expires_at'] <= datetime.now(timezone.utc).timestamp() + window
    assert registration['session_verified_at']

def test_revoked_or_disabled_session_removes_the_registration(db, sends, monkeypatch):
    device('one')
    guardian, identifier = case()
    expire_registrations(db)
    monkeypatch.setattr(sessions, 'verify_session', lambda uid, registration: 'revoked')
    sends.reset_mock()
    CaseService(guardian).cancel(identifier)
    assert sends.call_count == 0
    assert not any(p.startswith('users/one/fcm_registrations/') for p in db.data)

def test_transient_session_check_failure_skips_but_keeps_the_registration(db, sends, monkeypatch):
    device('one')
    guardian, identifier = case()
    expire_registrations(db)
    monkeypatch.setattr(sessions, 'verify_session', lambda uid, registration: 'unknown')
    sends.reset_mock()
    CaseService(guardian).cancel(identifier)
    assert sends.call_count == 0
    assert any(p.startswith('users/one/fcm_registrations/') for p in db.data)
    monkeypatch.setattr(sessions, 'verify_session', lambda uid, registration: 'valid')
    volunteer_alerts.dispatch(db, identifier)  # reconciliation succeeds once Firebase answers
    assert sends.call_count == 1

def test_verify_session_uses_firebase_revocation_semantics(monkeypatch):
    class User:
        def __init__(self, disabled, valid_after_ms):
            self.disabled, self.tokens_valid_after_timestamp = disabled, valid_after_ms
    monkeypatch.setattr(sessions, 'firebase_app', lambda: None)
    monkeypatch.setattr(sessions.auth, 'get_user', lambda uid, app=None: User(False, 1_000_000))
    assert sessions.verify_session('u', {'auth_time': 1_500}) == 'valid'
    assert sessions.verify_session('u', {'auth_time': 500}) == 'revoked'
    # Legacy registration without auth_time: its sign-in is dated one token
    # lifetime before its expiry (4000 - 3600 = 400 < 1000 -> revoked).
    assert sessions.verify_session('u', {'session_expires_at': 4_000}) == 'revoked'
    assert sessions.verify_session('u', {'session_expires_at': 5_000}) == 'valid'
    monkeypatch.setattr(sessions.auth, 'get_user', lambda uid, app=None: User(True, 0))
    assert sessions.verify_session('u', {'auth_time': 1_500}) == 'revoked'
    def offline(uid, app=None):
        raise ConnectionError('offline')
    monkeypatch.setattr(sessions.auth, 'get_user', offline)
    assert sessions.verify_session('u', {'auth_time': 1_500}) == 'unknown'

# --- Reconciliation & the maintenance boundary -----------------------------

def test_retry_alerts_covers_recently_closed_cases_but_not_reunited_or_old(db, monkeypatch):
    _, open_case = case()
    guardian, closed = case()
    db.data['cases/' + closed].update(status='cancelled', closed_at=datetime.now(timezone.utc))
    _, old = case()
    db.data['cases/' + old].update(status='resolved', closed_at=datetime.now(timezone.utc) - timedelta(days=2))
    _, reunited = case()
    db.data['cases/' + reunited].update(status='reunited', closed_at=datetime.now(timezone.utc))
    monkeypatch.setattr(local_jobs, 'database', lambda: db)
    dispatch = Mock()
    monkeypatch.setattr(local_jobs, 'dispatch', dispatch)
    local_jobs.retry_alerts()
    assert sorted(call.args[1] for call in dispatch.call_args_list) == sorted([open_case, closed])

def test_maintenance_endpoint_only_exists_for_the_configured_caller(monkeypatch):
    ran = Mock()
    monkeypatch.setattr(local_jobs, 'run_once', ran)
    monkeypatch.delenv('RADD_MAINTENANCE_TOKEN', raising=False)
    with TestClient(app) as client:
        assert client.post('/internal/maintenance', headers={'x-radd-maintenance-token': 'x'}).status_code == 404
    monkeypatch.setenv('RADD_MAINTENANCE_TOKEN', 'scheduler-secret')
    with TestClient(app) as client:
        assert client.post('/internal/maintenance').status_code == 404
        assert client.post('/internal/maintenance', headers={'x-radd-maintenance-token': 'wrong'}).status_code == 404
        assert ran.call_count == 0
        assert client.post('/internal/maintenance', headers={'x-radd-maintenance-token': 'scheduler-secret'}).json() == {'ran': True}
    assert ran.call_count == 1

def test_local_jobs_thread_is_opt_in_only(monkeypatch):
    monkeypatch.delenv('RADD_LOCAL_JOBS', raising=False)
    started = Mock()
    monkeypatch.setattr(main_module.LocalJobs, 'start', started)
    with TestClient(app):
        pass
    assert started.call_count == 0
