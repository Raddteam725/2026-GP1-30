import sys
from pathlib import Path
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import volunteer_workflow, service
from app.volunteer_workflow import FoundInput
from app.cases import CaseService
from app.case_models import CaseCreate
from app.main import app
from app.firebase import identity
from test_volunteer import db, vol, case
from test_cases import guardian_with_individual, photo

@pytest.fixture(autouse=True)
def photos(db, monkeypatch):
    monkeypatch.setattr(volunteer_workflow, 'bucket', service.bucket)

def submit(uid='one', request_id='request-00000000001'):
    return vol(uid).submit_found(FoundInput(request_id=request_id, photo_base64=photo()))

def matching(uid='one'):
    guardian, case_id = case()
    profile = vol(uid).profiles_list()[0]
    report = submit(uid)
    result = vol(uid).confirm(report['id'], profile['id'])
    return guardian, case_id, result

def test_found_upload_is_real_private_idempotent_and_ai_explicitly_unavailable(db):
    report = submit()
    retry = submit()
    assert report['id'] == retry['id']
    assert len([p for p in db.data if p.startswith('found_reports/')]) == 1
    assert 'photo_path' not in report
    assert vol().found_photo(report['id']).startswith(b'\xff\xd8')
    assert vol().candidates(report['id']) == {'state': 'unavailable', 'candidates': []}
    assert vol().found_list()[0]['id'] == report['id']
    with pytest.raises(HTTPException): vol('two').found_owned(report['id'])
    with pytest.raises(HTTPException): vol('two').found_photo(report['id'])
    with pytest.raises(HTTPException): vol('two').candidates(report['id'])

def test_profiles_are_real_event_scoped_and_do_not_leak_contact_or_paths(db):
    guardian, person = guardian_with_individual('guardian')
    profiles = vol().profiles_list()
    assert len(profiles) == 1
    assert profiles[0]['full_name'] == 'Missing Person'
    assert 'guardian' not in profiles[0] and 'photo_path' not in profiles[0]
    assert 'guardian_id' not in profiles[0]
    assert vol().registration_photo(profiles[0]['id']).startswith(b'\xff\xd8')
    db.data[guardian.user.collection('individuals').document(person).path]['event_id'] = 'other-event'
    assert vol().profiles_list() == []
    with pytest.raises(HTTPException): vol().registration_photo(profiles[0]['id'])

def test_confirm_manual_match_persists_shared_status_contact_and_other_volunteer_notification(db):
    guardian, case_id = case()
    vol().start_search(case_id)
    vol('two').start_search(case_id)
    profile = vol().profiles_list()[0]
    report = submit()
    result = vol().confirm(report['id'], profile['id'])
    assert result['status'] == 'match_confirmed'
    assert result['person']['guardian']['phone'] == '+966500000001'
    assert CaseService(guardian).list()[0]['status'] == 'match_confirmed'
    assert vol().list() == vol('two').list() == vol('two').list(True) == []
    assert vol().list(True)[0]['id'] == case_id
    assert vol('two').notifications_list()[0]['status'] == 'match_confirmed'
    assert vol().profiles_list() == []
    with pytest.raises(HTTPException): vol('two').public_found(vol('two').found_owned(report['id']))
    assert vol().confirm(report['id'], profile['id'])['case_id'] == case_id
    assert 'token_hash' not in str(result)

def test_found_before_missing_creates_one_shared_case_on_manual_confirmation(db):
    guardian, _ = guardian_with_individual('guardian')
    profile = vol().profiles_list()[0]
    report = submit()
    assert CaseService(guardian).list() == []
    result = vol().confirm(report['id'], profile['id'])
    assert result['case_id'].startswith('RD-')
    assert CaseService(guardian).list()[0]['id'] == result['case_id']
    assert result['status'] == 'match_confirmed'
    assert db.data['cases/' + result['case_id']]['source'] == 'found_report'

def test_qr_uses_existing_guardian_challenge_and_handover_survives_restart(db):
    guardian, case_id, report = matching()
    report_id = report['id']
    with pytest.raises(HTTPException): vol().handover_found(report_id)
    assert vol().begin_verification(report_id)['status'] == 'awaiting_guardian_verification'
    challenge = guardian.account_verification()
    assert 'guardian' not in challenge['payload'].split(':')[-1]
    with pytest.raises(HTTPException): vol('two').verify_guardian(report_id, challenge['payload'])
    assert not vol().verify_guardian(report_id, 'RD-FAKE')['verified']
    with pytest.raises(HTTPException): vol().handover_found(report_id)
    verified = vol().verify_guardian(report_id, challenge['payload'])
    assert verified['verified']
    assert verified['report']['status'] == 'awaiting_guardian_verification'
    assert 'token_hash' not in verified['report']['verification']
    assert vol().verify_guardian(report_id, challenge['payload'])['verified']  # lost-response retry
    # New service instance represents an app restart; receipt is in Firestore.
    assert vol().found_list()[0]['verification']['method'] == 'qr'
    result = vol().handover_found(report_id)
    assert result['status'] == 'reunited'
    assert result['handed_over_by'] == 'one'
    assert result['handed_over_at'] is not None
    assert CaseService(guardian).list()[0]['status'] == 'reunited'
    assert guardian.list()[0]['active_case_id'] is None
    assert vol().handover_found(report_id)['handed_over_at'] == result['handed_over_at']
    assert any(n['status'] == 'reunited' for n in CaseService(guardian).list_notifications())

def test_account_level_qr_scan_for_one_case_never_affects_a_sibling_case(db):
    # The QR is Guardian-account-level (one QR for the whole account), not
    # per-case -- so this is the one property that specifically needs proving:
    # verifying case A must not also verify, or otherwise touch, case B.
    guardian, person_a = guardian_with_individual('guardian')
    case_a = CaseService(guardian).create(CaseCreate(individual_id=person_a))['id']
    _, person_b = guardian_with_individual('guardian')
    case_b = CaseService(guardian).create(CaseCreate(individual_id=person_b))['id']
    profiles = {p['case_id']: p['id'] for p in vol().profiles_list()}
    report_a = submit('one', 'request-aaaaaaaaaaaaaaaa')
    report_b = submit('one', 'request-bbbbbbbbbbbbbbbb')
    vol().confirm(report_a['id'], profiles[case_a])
    vol().confirm(report_b['id'], profiles[case_b])
    vol().begin_verification(report_a['id'])
    vol().begin_verification(report_b['id'])
    qr = guardian.account_verification()
    assert vol().verify_guardian(report_a['id'], qr['payload'])['verified'] is True
    # The same (now single-use-consumed) token must not also verify case B.
    assert vol().verify_guardian(report_b['id'], qr['payload'])['verified'] is False
    assert db.data['cases/' + case_b]['status'] == 'awaiting_guardian_verification'
    assert db.data['cases/' + case_b].get('guardian_verification') is None
    with pytest.raises(HTTPException):
        vol().handover_found(report_b['id'])
    # A fresh account-level token still lets the Guardian verify the sibling case.
    qr2 = guardian.account_verification()
    assert vol().verify_guardian(report_b['id'], qr2['payload'])['verified'] is True
    result_b = vol().handover_found(report_b['id'])
    assert result_b['status'] == 'reunited'
    # Case A is wholly unaffected by case B's later, separate handover.
    assert db.data['cases/' + case_a]['status'] == 'awaiting_guardian_verification'

@pytest.mark.parametrize('failure', ['expired', 'wrong_guardian', 'wrong_event', 'consumed'])
def test_invalid_qr_cannot_authorize_handover(db, failure):
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    challenge = guardian.account_verification()
    row = db.data[f'users/{guardian.uid}/verification/current']
    if failure == 'expired': row['expires_at'] = datetime.now(timezone.utc) - timedelta(seconds=1)
    elif failure == 'wrong_guardian': row['guardian_id'] = 'other'
    elif failure == 'wrong_event': row['event_id'] = 'other'
    else: row['consumed_at'] = datetime.now(timezone.utc)
    assert vol().verify_guardian(report['id'], challenge['payload'])['verified'] is False
    with pytest.raises(HTTPException): vol().handover_found(report['id'])
    assert db.data['cases/' + case_id]['status'] == 'awaiting_guardian_verification'

def test_notification_materialization_and_read_are_persistent_and_isolated(db):
    _, case_id = case()
    notifications = vol().notifications_list()
    assert len(notifications) == 1 and notifications[0]['case_id'] == case_id
    assert vol().notifications_list()[0]['created_at'] == notifications[0]['created_at']
    vol().notification_read(notifications[0]['id'])
    assert vol().notifications_list()[0]['read_at'] is not None
    assert vol('two').notifications_list()[0]['read_at'] is None

def test_two_volunteers_cannot_confirm_same_profile_concurrently(db):
    _, case_id = case()
    profile_id = vol().profiles_list()[0]['id']
    reports = {uid: submit(uid)['id'] for uid in ['one', 'two']}
    barrier = Barrier(2)
    def confirm(uid):
        barrier.wait(timeout=5)
        try:
            vol(uid).confirm(reports[uid], profile_id)
            return uid
        except HTTPException as error:
            assert error.status_code == 409
            return None
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(confirm, ['one', 'two']))
    winner = [uid for uid in results if uid]
    assert len(winner) == 1
    assert db.data['cases/' + case_id]['confirmed_by'] == winner[0]

def test_api_rejects_client_identity_and_case_identifier_as_verification(db):
    _, _, report = matching()
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        assert client.post('/v1/volunteer/found-reports', json={'uid': 'two', 'request_id': 'request-00000000002', 'photo_base64': photo()}).status_code == 422
        assert client.post(f"/v1/volunteer/found-reports/{report['id']}/verify", json={'case_id': report['case_id'], 'authenticatedAccountShown': True}).status_code == 422
        result = client.get(f"/v1/volunteer/found-reports/{report['id']}")
        assert result.status_code == 200
        assert 'photo_path' not in result.text
    app.dependency_overrides.clear()

def test_inactive_and_guardian_are_rejected_by_workflow_endpoints(db):
    guardian_with_individual('guardian')
    for uid in ['guardian', 'two']:
        db.data['users/two']['active'] = False
        app.dependency_overrides[identity] = lambda uid=uid: {'uid': uid}
        with TestClient(app) as client:
            for path in ['/profiles', '/found-reports', '/notifications']:
                assert client.get('/v1/volunteer' + path).status_code == 403
            assert client.post('/v1/volunteer/found-reports', json={'request_id': 'request-00000000002', 'photo_base64': photo()}).status_code == 403
    app.dependency_overrides.clear()

def test_concurrent_upload_retry_keeps_one_report_and_one_photo(db):
    barrier = Barrier(2)
    def upload(_):
        barrier.wait(timeout=5)
        return submit()['id']
    with ThreadPoolExecutor(max_workers=2) as pool:
        ids = list(pool.map(upload, [1, 2]))
    assert ids[0] == ids[1]
    assert len([path for path in service.bucket().data if path.startswith('found/')]) == 1

def test_report_history_remains_readable_after_guardian_deletes_reunited_registration(db):
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    qr = guardian.account_verification()
    vol().verify_guardian(report['id'], qr['payload'])
    vol().handover_found(report['id'])
    guardian.delete(guardian.list()[0]['id'])
    history = vol().found_list()[0]
    assert history['status'] == 'reunited'
    assert history['person']['full_name'] == 'Missing Person'

def test_failed_report_save_removes_uploaded_photo(db):
    db.data.pop('events/test-event')
    with pytest.raises(HTTPException): submit()
    assert service.bucket().data == {}
    assert not [path for path in db.data if path.startswith('found_reports/')]

def test_admin_provision_command_uses_auth_identity_and_refuses_guardian_overwrite(db):
    from types import SimpleNamespace
    from scripts.provision_volunteer import provision
    provision(db, SimpleNamespace(uid='admin-created', email='real@example.test'), 'Real Volunteer', '+966500000001', 'VOL-001')
    data = db.data['users/admin-created']
    assert data['role'] == 'volunteer' and data['active'] is True
    assert data['created_at'] is not None and 'password' not in data
    guardian_with_individual('guardian')
    before = dict(db.data['users/guardian'])
    with pytest.raises(ValueError):
        provision(db, SimpleNamespace(uid='guardian', email='g@example.test'), 'No overwrite', '+966500000001', 'VOL-002')
    assert db.data['users/guardian'] == before

# --- Case Identifier: the case-specific alternative to the Guardian QR -----

def test_case_identifier_alternative_verification_is_case_specific_and_recorded(db):
    _, case_id, report = matching()
    report_id = report['id']
    vol().begin_verification(report_id)
    # A different (e.g. sibling) case's identifier is rejected: nothing is
    # recorded on this case and handover stays blocked.
    assert vol().verify_guardian_identifier(report_id, 'RD-OTHER')['verified'] is False
    assert db.data['cases/' + case_id].get('guardian_verification') is None
    with pytest.raises(HTTPException): vol().handover_found(report_id)
    # The identifier exactly as the Guardian's app displays it ("#RD-…", any case).
    result = vol().verify_guardian_identifier(report_id, '#' + case_id.lower())
    assert result['verified'] is True
    assert result['report']['verification']['method'] == 'case_identifier'
    assert 'token_hash' not in str(result)
    assert vol().verify_guardian_identifier(report_id, case_id)['verified'] is True  # lost-response retry
    handed = vol().handover_found(report_id)
    assert handed['status'] == 'reunited'
    # The handover record keeps saying HOW the Guardian was verified.
    assert db.data['cases/' + case_id]['guardian_verification']['method'] == 'case_identifier'
    assert db.data['cases/' + case_id]['handed_over_by'] == 'one'

def test_case_identifier_verification_requires_the_awaiting_stage_and_the_confirming_volunteer(db):
    _, case_id, report = matching()
    with pytest.raises(HTTPException): vol().verify_guardian_identifier(report['id'], case_id)  # still match_confirmed
    vol().begin_verification(report['id'])
    with pytest.raises(HTTPException): vol('two').verify_guardian_identifier(report['id'], case_id)
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        assert client.post(f"/v1/volunteer/found-reports/{report['id']}/verify-identifier", json={'case_id': case_id, 'uid': 'x'}).status_code == 422
        response = client.post(f"/v1/volunteer/found-reports/{report['id']}/verify-identifier", json={'case_id': case_id})
        assert response.status_code == 200 and response.json()['verified'] is True
    app.dependency_overrides.clear()

# --- Guardian is notified of every Volunteer-driven status change ---------

def test_volunteer_driven_stages_write_guardian_notifications_and_push(db, monkeypatch):
    from app import push
    sent = []
    monkeypatch.setattr(push, 'notify_guardian', lambda uid, **kw: sent.append((uid, kw['status'])))
    monkeypatch.setattr(volunteer_workflow, 'notify_guardian', lambda uid, **kw: sent.append((uid, kw['status'])))
    from app import volunteer as volunteer_module
    monkeypatch.setattr(volunteer_module, 'notify_guardian', lambda uid, **kw: sent.append((uid, kw['status'])))
    guardian, case_id = case()
    vol().start_search(case_id)
    vol('two').start_search(case_id)  # A second join changes nothing the Guardian sees.
    profile = vol().profiles_list()[0]
    report = submit()
    vol().confirm(report['id'], profile['id'])
    vol().begin_verification(report['id'])
    vol().begin_verification(report['id'])  # idempotent: no duplicate record/push
    qr = guardian.account_verification()
    vol().verify_guardian(report['id'], qr['payload'])
    vol().handover_found(report['id'])
    statuses = [n['status'] for n in CaseService(guardian).list_notifications()]
    assert sorted(statuses) == sorted(['report_received', 'search_in_progress', 'match_confirmed', 'awaiting_guardian_verification', 'reunited'])
    assert all(uid == guardian.uid for uid, _ in sent)
    assert [status for _, status in sent] == ['search_in_progress', 'match_confirmed', 'awaiting_guardian_verification', 'reunited']


def test_qr_uses_existing_guardian_challenge_and_handover_survives_restart_legacy_case_qr(db):
    guardian, case_id, report = matching()
    report_id = report['id']
    with pytest.raises(HTTPException): vol().handover_found(report_id)
    assert vol().begin_verification(report_id)['status'] == 'awaiting_guardian_verification'
    challenge = CaseService(guardian).verification(case_id)
    assert 'guardian' not in challenge['payload'].split(':')[-1]
    with pytest.raises(HTTPException): vol('two').verify_guardian(report_id, challenge['payload'])
    assert not vol().verify_guardian(report_id, 'RD-FAKE')['verified']
    with pytest.raises(HTTPException): vol().handover_found(report_id)
    verified = vol().verify_guardian(report_id, challenge['payload'])
    assert verified['verified']
    assert verified['report']['status'] == 'awaiting_guardian_verification'
    assert 'token_hash' not in verified['report']['verification']
    assert vol().verify_guardian(report_id, challenge['payload'])['verified']  # lost-response retry
    # New service instance represents an app restart; receipt is in Firestore.
    assert vol().found_list()[0]['verification']['method'] == 'qr'
    result = vol().handover_found(report_id)
    assert result['status'] == 'reunited'
    assert result['handed_over_by'] == 'one'
    assert result['handed_over_at'] is not None
    assert CaseService(guardian).list()[0]['status'] == 'reunited'
    assert guardian.list()[0]['active_case_id'] is None
    assert vol().handover_found(report_id)['handed_over_at'] == result['handed_over_at']
    assert any(n['status'] == 'reunited' for n in CaseService(guardian).list_notifications())


@pytest.mark.parametrize('failure', ['expired', 'wrong_guardian', 'wrong_event', 'consumed'])
def test_invalid_qr_cannot_authorize_handover_legacy_case_qr(db, failure):
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    challenge = CaseService(guardian).verification(case_id)
    row = db.data[f'cases/{case_id}/verification/current']
    if failure == 'expired': row['expires_at'] = datetime.now(timezone.utc) - timedelta(seconds=1)
    elif failure == 'wrong_guardian': row['guardian_id'] = 'other'
    elif failure == 'wrong_event': row['event_id'] = 'other'
    else: row['consumed_at'] = datetime.now(timezone.utc)
    assert vol().verify_guardian(report['id'], challenge['payload'])['verified'] is False
    with pytest.raises(HTTPException): vol().handover_found(report['id'])
    assert db.data['cases/' + case_id]['status'] == 'awaiting_guardian_verification'


def test_report_history_remains_readable_after_guardian_deletes_reunited_registration_legacy_case_qr(db):
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    qr = CaseService(guardian).verification(case_id)
    vol().verify_guardian(report['id'], qr['payload'])
    vol().handover_found(report['id'])
    guardian.delete(guardian.list()[0]['id'])
    history = vol().found_list()[0]
    assert history['status'] == 'reunited'
    assert history['person']['full_name'] == 'Missing Person'

# Shared contracts introduced by merging Guardian lifecycle work with Volunteer.
def test_guardian_cancel_does_not_break_volunteer_found_report_feed(db):
    guardian, case_id, report = matching()
    CaseService(guardian).cancel(case_id)
    assert vol().found_list() == []
    assert vol().list() == [] and vol().list(True) == []
    assert db.data['found_reports/' + report['id']]['case_id'] == case_id
    with pytest.raises(HTTPException): vol().begin_verification(report['id'])

def test_volunteer_handover_sets_guardian_retention_metadata(db):
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    qr = guardian.account_verification()
    vol().verify_guardian(report['id'], qr['payload'])
    vol().handover_found(report['id'])
    data = db.data['cases/' + case_id]
    assert data['closed_at'] == data['handed_over_at'] or data['closed_at'] >= data['handed_over_at']
    assert data['age_group'] == '6-12'

def test_expired_guardian_photo_is_not_served_or_matched_by_volunteer(db):
    guardian, case_id = case()
    profile_id = vol().profiles_list()[0]['id']
    person_id = guardian.list()[0]['id']
    db.data[f'users/{guardian.uid}/individuals/{person_id}']['photo_captured_at'] = datetime.now(timezone.utc) - timedelta(hours=25)
    assert vol().profiles_list() == []
    for action in [lambda: vol().photo(case_id), lambda: vol().registration_photo(profile_id)]:
        with pytest.raises(HTTPException) as error: action()
        assert error.value.status_code == 404
    report = submit()
    with pytest.raises(HTTPException): vol().confirm(report['id'], profile_id)

def test_wrong_identifier_after_valid_one_clears_receipt(db):
    _, case_id, report = matching()
    vol().begin_verification(report['id'])
    assert vol().verify_guardian_identifier(report['id'], case_id)['verified']
    assert not vol().verify_guardian_identifier(report['id'], 'RD-WRONG')['verified']
    with pytest.raises(HTTPException): vol().handover_found(report['id'])

def test_unknown_account_challenge_rejects_instead_of_crashing(db):
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    assert not vol().verify_guardian(report['id'], f'radd:guardian-verification:v1:{guardian.uid}:unknown')['verified']
