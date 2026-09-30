import pytest
from fastapi import HTTPException
from app.volunteer_access import VolunteerManagement, assignment_ref
from app.models import FcmUnregister
from test_volunteer import db, vol, case


def test_profile_api_reports_existing_active_event_assignment(db):
    from fastapi.testclient import TestClient
    from app.main import app
    from app.firebase import identity

    # Existence is sufficient: no legacy assigned/active field is required.
    assert db.data['events/test-event/volunteers/one'] == {}
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        for _ in range(2):  # A fresh profile request must reload the same access.
            response = client.get('/v1/volunteer')
            assert response.status_code == 200
            profile = response.json()
            assert profile['active'] is True
            assert profile['assigned'] is True
            assert profile['event_id'] == 'test-event'


def test_existence_is_assignment_even_without_fields_and_status_is_independent(db):
    management = VolunteerManagement(db)
    management.change('one', actor='test-operator', operation='remove', event_id='test-event')
    assert vol().profile(require_assignment=False)['assigned'] is False
    assert db.data['users/one']['active'] is True
    with pytest.raises(HTTPException) as error: vol().list()
    assert error.value.detail == 'event_access_required'
    management.change('one', actor='test-operator', operation='assign', event_id='test-event')
    assert vol().profile()['assigned'] is True
    assert set(assignment_ref(db, 'test-event', 'one').get().to_dict()) == {'updated_at', 'updated_by'}
    management.change('one', actor='test-operator', operation='deactivate')
    assert assignment_ref(db, 'test-event', 'one').get().exists
    with pytest.raises(HTTPException) as error: vol().list()
    assert error.value.detail == 'volunteer_inactive'
    management.change('one', actor='test-operator', operation='enable')
    assert vol().profile()['assigned'] is True


def test_removal_revokes_existing_case_access_without_mutating_case(db):
    _, identifier = case()
    vol().start_search(identifier)
    before = dict(db.data['cases/' + identifier])
    VolunteerManagement(db).change('one', actor='test', operation='remove', event_id='test-event')
    for action in (lambda: vol().start_search(identifier), lambda: vol().accessible(identifier),
                   lambda: vol().profiles_list(), lambda: vol().found_list(),
                   lambda: vol().notifications_list()):
        with pytest.raises(HTTPException): action()
    assert db.data['cases/' + identifier] == before
    vol().unregister_device(FcmUnregister(token='test-device'))


def test_event_end_and_other_event_assignment_do_not_authorize_current_event(db):
    db.data['events/test-event']['active'] = False
    assert vol().profile(require_assignment=False)['event_id'] is None
    assert vol().profile(require_assignment=False)['assigned'] is False
    db.set(db.collection('events').document('next'), {'active': True})
    assert vol().profile(require_assignment=False)['assigned'] is False
    with pytest.raises(HTTPException): vol().profiles_list()


def test_management_rejects_guardian_missing_user_and_missing_event(db):
    management = VolunteerManagement(db)
    db.set(db.collection('users').document('guardian'), {'role': 'guardian'})
    for uid in ('guardian', 'absent'):
        with pytest.raises(ValueError): management.change(uid, actor='test', operation='deactivate')
    with pytest.raises(ValueError):
        management.change('one', actor='test', operation='assign', event_id='absent')


def test_management_sends_only_nonsensitive_access_hint(db, monkeypatch):
    from app import volunteer_access
    sent = []
    monkeypatch.setattr(volunteer_access, 'firebase_app', lambda: None)
    monkeypatch.setattr(volunteer_access.messaging, 'send', lambda message, app: sent.append(message))
    db.set(db.collection('users').document('one').collection('fcm_registrations').document('device'), {'token': 'test-device'})
    VolunteerManagement(db).change('one', actor='test', operation='deactivate')
    assert len(sent) == 1
    assert sent[0].data == {'role': 'volunteer', 'kind': 'access_changed'}
    assert db.data['users/one']['active'] is False


def test_unassigned_volunteer_gets_no_new_case_history_or_queued_delivery(db, monkeypatch):
    from app import volunteer_alerts
    VolunteerManagement(db).change('one', actor='test', operation='remove', event_id='test-event')
    _, case_id = case()
    volunteer_alerts.dispatch(db, case_id)
    assert not list(db.collection('users').document('one').collection('volunteer_notifications').stream())
    monkeypatch.setattr(volunteer_alerts.messaging, 'send', lambda *a, **kw: pytest.fail('Unassigned push'))
    user = db.collection('users').document('one').get()
    case_doc = db.collection('cases').document(case_id).get()
    # Assignment is checked before reading the old queued registration/ref.
    volunteer_alerts._send_registration(db, user, case_doc, 'general', None, None)


def test_event_switch_between_profile_and_query_cannot_expose_unassigned_event(db, monkeypatch):
    service = vol()
    original = service.profile
    def switch_after_profile(*args, **kwargs):
        profile = original(*args, **kwargs)
        db.data['events/test-event']['active'] = False
        db.set(db.collection('events').document('next'), {'active': True})
        return profile
    monkeypatch.setattr(service, 'profile', switch_after_profile)
    with pytest.raises(HTTPException) as error:
        service.list()
    assert error.value.detail == 'event_access_required'


def test_badge_event_name_uses_current_assigned_event_not_user_snapshot(db):
    from app.events import active_event, event_summary
    db.data['users/one']['event_name'] = 'Stale profile name'
    db.data['events/test-event']['name'] = 'Current event'
    assert vol().profile()['event_name'] == event_summary(active_event(db))['name']
    db.data['events/test-event']['name'] = 'Renamed event'
    assert vol().profile()['event_name'] == 'Renamed event'
    del db.data['events/test-event/volunteers/one']
    assert vol().profile(require_assignment=False)['event_name'] is None
    db.data['events/test-event']['active'] = False
    assert vol().profile(require_assignment=False)['event_name'] is None
