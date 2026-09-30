import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from datetime import datetime, timedelta, timezone
from unittest.mock import Mock
from types import SimpleNamespace
import pytest
from app import volunteer_alerts
from app.volunteer import VolunteerDevice
from app.cases import CaseService
from app.case_models import GuidedReport
from test_volunteer import db, vol, case

@pytest.fixture
def sends(monkeypatch):
    send = Mock(return_value='message-id')
    monkeypatch.setattr(volunteer_alerts.messaging, 'send', send)
    monkeypatch.setattr(volunteer_alerts, 'firebase_app', lambda: None)
    monkeypatch.setattr(volunteer_alerts.auth, 'get_user', lambda *args, **kwargs: SimpleNamespace(disabled=False, tokens_valid_after_timestamp=0))
    return send

def device(uid, **kwargs):
    return vol(uid, exp=(datetime.now(timezone.utc)+timedelta(hours=1)).timestamp()).register_device(
        VolunteerDevice(token='device-'+uid, locale='ar', **kwargs))

def test_history_committed_before_async_send_and_logout_before_worker_blocks_delivery(db, sends, monkeypatch):
    from app import delivery_queue
    device('one')
    pending = []
    monkeypatch.setattr(delivery_queue, 'submit', lambda key, operation: pending.append(operation))
    _, identifier = case()
    assert pending
    assert db.collection('cases').document(identifier).get().exists
    assert db.collection('users').document('one').collection('volunteer_notifications').document(identifier + '-new').get().exists
    assert sends.call_count == 0
    for ref in list(db.collection('users').document('one').collection('fcm_registrations').stream()):
        ref.reference.delete()
    for send in pending:
        send()
    assert sends.call_count == 0

def test_general_and_priority_use_real_case_and_do_not_duplicate_on_retry(db, sends):
    device('one', latitude=24.7, longitude=46.7)
    device('two', latitude=25.7, longitude=46.7)
    guardian, identifier = case()
    assert sends.call_count == 2
    assert all(call.args[0].data['case_id'] == identifier for call in sends.call_args_list)
    CaseService(guardian).save_report(identifier, GuidedReport(same_location=True, latitude=24.7, longitude=46.7))
    assert sends.call_count == 3
    assert sends.call_args.args[0].data['kind'] == 'priority'
    assert sends.call_args.args[0].token == 'device-one'
    volunteer_alerts.dispatch(db, identifier)
    assert sends.call_count == 3
    assert len([p for p in db.data if p.startswith('cases/')]) == 1

def test_no_location_inactive_expired_or_terminal_receives_no_priority(db, sends):
    device('one')
    device('two')
    guardian, identifier = case()
    CaseService(guardian).save_report(identifier, GuidedReport(same_location=True, latitude=24.7, longitude=46.7))
    assert sends.call_count == 2
    db.data['users/one']['active'] = False
    for path, data in db.data.items():
        if '/fcm_registrations/' in path: data['session_expires_at'] = 0
    sends.reset_mock()
    volunteer_alerts.dispatch(db, identifier)
    assert sends.call_count == 0
    CaseService(guardian).cancel(identifier)
    volunteer_alerts.dispatch(db, identifier)
    assert sends.call_count == 0

def test_push_failure_is_retryable_and_never_undoes_guardian_case(db, sends):
    device('one')
    sends.side_effect = OSError('offline')
    guardian, identifier = case()
    assert CaseService(guardian).list()[0]['id'] == identifier
    assert not any('/deliveries/' in path for path in db.data)
    sends.side_effect = None
    volunteer_alerts.dispatch(db, identifier)
    assert any('/deliveries/' in path for path in db.data)


def test_registration_moves_same_device_between_roles(db, sends):
    guardian, _ = case()
    guardian.register_fcm_token('same-device')
    vol('one', exp=9999999999).register_device(VolunteerDevice(token='same-device'))
    assert not list(guardian.user.collection('fcm_registrations').stream())
    guardian.register_fcm_token('same-device')
    assert not list(vol().user.collection('fcm_registrations').stream())


def test_confirm_notifies_other_joined_volunteer_only(db, sends, monkeypatch):
    from app import volunteer_workflow, service
    from app.volunteer_workflow import FoundInput
    from test_cases import photo
    monkeypatch.setattr(volunteer_workflow, 'bucket', service.bucket)
    device('one')
    device('two')
    guardian, identifier = case()
    vol().start_search(identifier)
    vol('two').start_search(identifier)
    found = vol().submit_found(FoundInput(request_id='real-report-request-1', photo_base64=photo()))
    profile = vol().profiles_list()[0]['id']
    sends.reset_mock()
    vol().confirm(found['id'], profile)
    assert sends.call_count == 1
    assert sends.call_args.args[0].token == 'device-two'
    assert sends.call_args.args[0].data['kind'] == 'status_update'
    assert 'Missing Person' not in str(sends.call_args)


def test_stale_or_cleared_location_cannot_trigger_priority(db, sends):
    device('one', latitude=24.7, longitude=46.7)
    for path, data in db.data.items():
        if '/fcm_registrations/' in path:
            data['location']['at'] = datetime.now(timezone.utc)-timedelta(minutes=2)
    guardian, identifier = case()
    CaseService(guardian).save_report(identifier, GuidedReport(same_location=True, latitude=24.7, longitude=46.7))
    assert sends.call_count == 1
    device('one')
    volunteer_alerts.dispatch(db, identifier)
    assert sends.call_count == 1

@pytest.mark.parametrize('outcome', ['cancelled', 'resolved'])
def test_guardian_closure_notifies_received_and_joined_once_and_keeps_history(db, sends, outcome):
    device('one')
    device('two')
    guardian, identifier = case()
    vol('two').start_search(identifier)
    # An unrelated account created after the report did not receive/join it.
    db.collection('users').document('unrelated').set({'role': 'volunteer', 'active': True})
    sends.reset_mock()
    getattr(CaseService(guardian), 'cancel' if outcome == 'cancelled' else 'resolve')(identifier)
    assert sends.call_count == 2
    for call in sends.call_args_list:
        message = call.args[0]
        assert message.data['kind'] == outcome
        assert message.data['notification_id'] == identifier + '-' + outcome
        assert message.android.priority == 'high'
        assert message.android.notification.tag == message.data['notification_id']
    volunteer_alerts.dispatch(db, identifier)
    assert sends.call_count == 2
    for uid in ('one', 'two'):
        history = vol(uid).notifications_list()
        assert {row['kind'] for row in history} == {'new_case', outcome}
        assert vol(uid).list() == vol(uid).list(True) == []
    assert not list(db.collection('users').document('unrelated').collection('volunteer_notifications').stream())


def test_history_does_not_depend_on_fcm_permission_or_device(db, sends):
    guardian, identifier = case()
    assert sends.call_count == 0
    assert vol().notifications_list()[0]['id'] == identifier + '-new'
    CaseService(guardian).cancel(identifier)
    assert sends.call_count == 0
    assert vol().notifications_list()[0]['kind'] == 'cancelled'


def test_closure_delivery_retries_and_does_not_recreate_expired_history(db, sends):
    device('one')
    guardian, identifier = case()
    sends.side_effect = OSError('temporary offline')
    CaseService(guardian).resolve(identifier)
    note = db.collection('users').document('one').collection('volunteer_notifications').document(identifier + '-resolved')
    assert note.get().exists
    assert not list(note.collection('deliveries').stream())
    sends.side_effect = None
    volunteer_alerts.dispatch(db, identifier)
    assert list(note.collection('deliveries').stream())
    sends.reset_mock()
    db.data['cases/' + identifier]['closed_at'] = datetime.now(timezone.utc) - timedelta(hours=24)
    note.delete()
    volunteer_alerts.dispatch(db, identifier)
    assert not note.get().exists
    assert sends.call_count == 0


def test_unchanged_device_heartbeat_does_not_redispatch_all_cases(db, sends, monkeypatch):
    from app import volunteer
    device('one', latitude=24.7, longitude=46.7)
    case()
    dispatch = Mock()
    monkeypatch.setattr(volunteer, 'safe_dispatch', dispatch)
    device('one', latitude=24.7, longitude=46.7)
    dispatch.assert_not_called()
    device('one', latitude=24.8, longitude=46.7)
    dispatch.assert_not_called()


def test_reunited_delivery_uses_successful_qr_handover_and_stable_history(db, sends, monkeypatch):
    from test_volunteer_workflow import matching
    from app import volunteer_workflow, service
    monkeypatch.setattr(volunteer_workflow, 'bucket', service.bucket)
    device('one')
    device('two')
    guardian, identifier, report = matching()
    vol().begin_verification(report['id'])
    qr = guardian.account_verification()
    assert vol().verify_guardian(report['id'], qr['payload'])['verified']
    sends.reset_mock()
    vol().handover_found(report['id'])
    assert sends.call_count == 2
    assert all(call.args[0].data['kind'] == 'reunited' for call in sends.call_args_list)
    assert vol('two').notifications_list()[0]['id'] == identifier + '-reunited'
    vol().handover_found(report['id'])
    assert sends.call_count == 2


def test_approved_id_token_expiry_stops_push_but_preserves_real_history(db, sends):
    device('one')
    for path, data in db.data.items():
        if '/fcm_registrations/' in path:
            data['session_expires_at'] = 0
    guardian, identifier = case()
    assert sends.call_count == 0
    assert vol().profile()['active'] is True
    assert vol().notifications_list()[0]['id'] == identifier + '-new'
    CaseService(guardian).cancel(identifier)
    assert sends.call_count == 0
    assert vol().notifications_list()[0]['kind'] == 'cancelled'


@pytest.mark.parametrize('disabled,valid_after', [(True, 0), (False, 2000000)])
def test_revoked_or_disabled_auth_session_never_receives_push(db, sends, monkeypatch, disabled, valid_after):
    monkeypatch.setattr(volunteer_alerts.auth, 'get_user', lambda *args, **kwargs:
        SimpleNamespace(disabled=disabled, tokens_valid_after_timestamp=valid_after))
    vol('one', exp=9999999999, auth_time=1000).register_device(VolunteerDevice(token='session-device'))
    _, identifier = case()
    assert sends.call_count == 0
    assert vol().notifications_list()[0]['id'] == identifier + '-new'


def test_normal_id_token_renewal_extends_same_device_without_duplicate_registration(db, sends):
    vol('one', exp=1, auth_time=1000).register_device(VolunteerDevice(token='session-device'))
    case()
    assert sends.call_count == 0
    vol('one', exp=9999999999, auth_time=1000).register_device(VolunteerDevice(token='session-device'))
    registrations=list(vol().user.collection('fcm_registrations').stream())
    assert len(registrations)==1
    assert registrations[0].to_dict()['session_expires_at']==9999999999
    assert registrations[0].to_dict()['session_auth_time']==1000
    assert sends.call_count==0
    vol('one', exp=9999999999, auth_time=1000).register_device(VolunteerDevice(token='session-device'))
    assert sends.call_count==0


def test_session_validation_failure_fails_closed_and_retries(db, sends, monkeypatch):
    device('one')
    monkeypatch.setattr(volunteer_alerts.auth, 'get_user', Mock(side_effect=OSError('offline')))
    _, identifier = case()
    assert sends.call_count==0
    monkeypatch.setattr(volunteer_alerts.auth, 'get_user', lambda *args, **kwargs:
        SimpleNamespace(disabled=False,tokens_valid_after_timestamp=0))
    volunteer_alerts.dispatch(db,identifier)
    assert sends.call_count==1

@pytest.mark.parametrize('outcome', ['cancelled', 'resolved'])
def test_confirmed_only_recipient_without_history_or_device_is_not_lost(db, sends, outcome):
    guardian, identifier = case()
    for note in list(vol('one').user.collection('volunteer_notifications').stream()):
        note.reference.delete()
    db.data['cases/' + identifier].update(confirmed_by='one', joined_by=[])
    getattr(CaseService(guardian), 'cancel' if outcome == 'cancelled' else 'resolve')(identifier)
    note = vol('one').user.collection('volunteer_notifications').document(identifier + '-' + outcome).get()
    assert note.to_dict()['kind'] == outcome
    assert sends.call_count == 0


def test_registration_rotation_logout_history_and_refresh_never_replay(db, sends):
    device('one')
    _, identifier = case()
    assert sends.call_count == 1
    ref = vol().user.collection('volunteer_notifications').document(identifier + '-new')
    original = ref.get().to_dict()
    device('one')
    volunteer_alerts.dispatch(db, identifier)
    vol().notifications_list()
    assert sends.call_count == 1
    for registration in vol().user.collection('fcm_registrations').stream():
        registration.reference.delete() # Isolated fixture models logout.
    vol('one', exp=9999999999).register_device(VolunteerDevice(token='rotated-device'))
    volunteer_alerts.dispatch(db, identifier) # Recovery job must not replay either.
    assert sends.call_count == 1
    assert ref.get().to_dict() == original
    from test_cases import guardian_with_individual
    from app.case_models import CaseCreate
    guardian, individual = guardian_with_individual('next-guardian')
    new_id = CaseService(guardian).create(CaseCreate(individual_id=individual))['id']
    assert sends.call_count == 2
    assert sends.call_args.args[0].data['case_id'] == new_id
    assert sends.call_args.args[0].android.notification.channel_id == 'radd_volunteer_alerts'


def test_unused_consent_fields_do_not_block_queued_push_or_notification_history(db, sends, monkeypatch):
    from app import delivery_queue
    device('one')
    pending = []
    monkeypatch.setattr(delivery_queue, 'submit', lambda key, operation: pending.append(operation))
    _, identifier = case()
    assert pending
    db.data['users/one']['privacy_version'] = 'obsolete'
    for send in pending:
        send()
    assert sends.call_count == 1
    _, next_id = case()
    assert db.collection('users').document('one').collection('volunteer_notifications').document(next_id + '-new').get().exists
