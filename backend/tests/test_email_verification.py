"""API authorization tests use the real verification gate, mocked Firebase only."""
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from fastapi.routing import APIRoute

from app import firebase, service, volunteer
from app.main import app
from firestore_fake import Database, configured_event


@pytest.fixture
def api(monkeypatch):
    db = Database()
    db.set(db.collection('events').document('test-event'), configured_event())
    db.set(db.collection('users').document('guardian'), {
        'role': 'guardian', 'full_name': 'Guardian', 'phone': '+966500000001',
    })
    monkeypatch.setattr(service, 'database', lambda: db)
    monkeypatch.setattr(volunteer, 'database', lambda: db)
    monkeypatch.setattr(service.firestore, 'transactional', lambda fn: fn)
    token = {'uid': 'guardian', 'email': 'guardian@example.test', 'email_verified': False}
    record = SimpleNamespace(email='guardian@example.test', email_verified=False, disabled=False)
    monkeypatch.setattr(firebase.auth, 'verify_id_token', lambda *a, **k: dict(token))
    monkeypatch.setattr(firebase.auth, 'get_user', lambda *a, **k: record)
    with TestClient(app) as client:
        yield client, db, token, record


PROFILE = {'full_name': 'Guardian', 'phone': '+966500000001',
           'age_confirmed': True, 'privacy_accepted': True}


def test_every_guardian_route_rejects_unverified_identity(api):
    client, db, token, record = api
    # Bodies cover every existing protected mobile Guardian endpoint. Keeping
    # the route inventory assertion makes additions require an explicit audit.
    bodies = {
        ('PUT', '/v1/guardian'): PROFILE,
        ('PATCH', '/v1/guardian'): {'full_name': 'Guardian', 'phone': '+966500000001'},
        ('PUT', '/v1/guardian/fcm-registrations'): {'token': 'x' * 40, 'locale': 'en'},
        ('POST', '/v1/guardian/fcm-registrations/unregister'): {'token': 'x' * 40},
        ('POST', '/v1/individuals'): {'full_name': 'Person', 'age': 0, 'gender': 'female', 'relationship': 'child'},
        ('PUT', '/v1/individuals/{item_id}'): {'full_name': 'Person', 'age': 130, 'gender': 'male', 'relationship': 'child'},
        ('POST', '/v1/cases'): {'individual_id': 'person'},
        ('PUT', '/v1/cases/{case_id}/guided-report'): {'clothing': 'Blue'},
    }
    protected = [(method, route.path) for route in app.routes if isinstance(route, APIRoute)
                 and route.path.startswith('/v1/') and route.path != '/v1/session'
                 and not route.path.startswith('/v1/volunteer') for method in route.methods]
    assert len(protected) == 26
    before = dict(db.data)
    for method, path in protected:
        resolved = path.replace('{item_id}', 'person').replace('{case_id}', 'case').replace('{notification_id}', 'notice')
        response = client.request(method, resolved, headers={'Authorization': 'Bearer signed-token'},
                                  json=bodies.get((method, path)))
        assert response.status_code == 403, (method, path, response.text)
        assert response.json()['detail'] == 'email_verification_required'
    assert db.data == before


@pytest.mark.parametrize('claim,verified,email', [
    (False, True, 'guardian@example.test'),  # cached unverified token
    (True, False, 'guardian@example.test'),  # stale formerly verified claim
    (True, True, 'changed@example.test'),   # old email token after correction
    (None, True, 'guardian@example.test'),  # legacy/missing claim
])
def test_stale_or_missing_claim_cannot_bypass_live_auth(api, claim, verified, email):
    client, db, token, record = api
    token['email_verified'] = claim
    record.email_verified, record.email = verified, email
    assert client.get('/v1/guardian', headers={'Authorization': 'Bearer token'}).status_code == 403
    assert client.put('/v1/guardian', json=PROFILE, headers={'Authorization': 'Bearer token'}).status_code == 403


def test_profile_creation_requires_verification_and_remains_idempotent(api):
    client, db, token, record = api
    del db.data['users/guardian']
    headers = {'Authorization': 'Bearer token'}
    assert client.get('/v1/session', headers=headers).status_code == 404
    assert client.put('/v1/guardian', json=PROFILE, headers=headers).status_code == 403
    assert 'users/guardian' not in db.data
    token['email_verified'] = record.email_verified = True
    for _ in range(2):
        response = client.put('/v1/guardian', json=PROFILE, headers=headers)
        assert response.status_code == 200
        assert response.json()['email'] == record.email
    assert len([p for p in db.data if p.startswith('users/')]) == 1


def test_live_auth_errors_fail_closed(api, monkeypatch):
    client, db, token, record = api
    token['email_verified'] = record.email_verified = True
    record.disabled = True
    headers = {'Authorization': 'Bearer token'}
    assert client.get('/v1/guardian', headers=headers).status_code == 401
    def unavailable(*a, **k):
        raise ConnectionError('offline')
    monkeypatch.setattr(firebase.auth, 'get_user', unavailable)
    assert client.get('/v1/guardian', headers=headers).status_code == 503


def test_role_resolution_is_minimal_and_volunteers_keep_existing_access(api):
    client, db, token, record = api
    headers = {'Authorization': 'Bearer token'}
    assert client.get('/v1/session', headers=headers).json() == {'role': 'guardian'}
    # A client-selected/custom role cannot turn a Guardian into a Volunteer.
    token['role'] = 'volunteer'
    assert client.get('/v1/session', headers=headers).status_code == 403
    assert client.get('/v1/volunteer', headers=headers).status_code == 403
    db.set(db.collection('users').document('guardian'), {
        'role': 'volunteer', 'active': True, 'full_name': 'Volunteer', 'volunteer_id': 'V1',
    })
    db.set(db.collection('events').document('test-event').collection('volunteers').document('guardian'), {})
    assert client.get('/v1/session', headers=headers).json() == {'role': 'volunteer'}
    assert client.get('/v1/volunteer', headers=headers).status_code == 200
    assert client.get('/v1/event', headers=headers).status_code == 200
    assert client.put('/v1/guardian', json=PROFILE, headers=headers).status_code == 403


@pytest.mark.parametrize('claim_role', [None, 'volunteer'])
@pytest.mark.parametrize('verified', [False, True])
def test_volunteer_guardian_requests_keep_original_role_errors(api, monkeypatch, claim_role, verified):
    client, db, token, record = api
    token['role'], token['email_verified'] = claim_role, verified
    db.data['users/guardian']['role'] = 'volunteer'
    def unexpected_lookup(*args, **kwargs):
        raise AssertionError('Guardian email gate must not run for a Volunteer')
    monkeypatch.setattr(firebase.auth, 'get_user', unexpected_lookup)
    headers = {'Authorization': 'Bearer token'}
    for response in (client.get('/v1/guardian', headers=headers),
                     client.put('/v1/guardian', json=PROFILE, headers=headers)):
        assert response.status_code == 403
        assert response.json()['detail'] == 'guardian_required'
