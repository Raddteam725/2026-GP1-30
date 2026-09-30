"""Organizational onboarding does not create a runtime consent prerequisite."""
import copy
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.firebase import identity
from test_volunteer import db, vol

@pytest.mark.parametrize('legacy', [{}, {'terms_version': 'obsolete', 'privacy_version': 'obsolete'},
    {'terms_version': 'draft-2026-09', 'privacy_version': 'draft-2026-09',
     'terms_accepted_at': None, 'privacy_accepted_at': None}])
def test_missing_or_outdated_consent_never_controls_access_or_is_migrated(db, legacy):
    db.data['users/one'].update(legacy)
    before = copy.deepcopy(db.data['users/one'])
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        profile = client.get('/v1/volunteer')
        assert profile.status_code == 200
        assert profile.json()['assigned'] is True
        assert profile.json()['event_id'] == 'test-event'
        assert 'consent_current' not in profile.json()
        for path in ('cases/available', 'cases/mine', 'profiles', 'found-reports', 'notifications'):
            assert client.get('/v1/volunteer/' + path).status_code == 200
    assert db.data['users/one'] == before
    assert '/v1/volunteer/consent' not in app.openapi()['paths']

@pytest.mark.parametrize('condition,detail', [('inactive', 'volunteer_inactive'),
    ('unassigned', 'event_access_required'), ('wrong_role', 'volunteer_required')])
def test_operational_account_and_assignment_requirements_remain(db, condition, detail):
    from fastapi import HTTPException
    if condition == 'inactive': db.data['users/one']['active'] = False
    if condition == 'unassigned': del db.data['events/test-event/volunteers/one']
    if condition == 'wrong_role': db.data['users/one']['role'] = 'guardian'
    with pytest.raises(HTTPException) as error: vol().list()
    assert error.value.detail == detail
