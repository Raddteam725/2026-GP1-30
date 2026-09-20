import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from datetime import datetime, timedelta, timezone
from unittest.mock import Mock
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
    return send

def device(uid, **kwargs):
    return vol(uid, exp=(datetime.now(timezone.utc)+timedelta(hours=1)).timestamp()).register_device(
        VolunteerDevice(token='device-'+uid, locale='ar', **kwargs))

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
