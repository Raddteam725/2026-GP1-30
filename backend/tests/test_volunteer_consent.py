"""Consent enforcement tests use isolated Firestore; no live acceptance writes."""
from datetime import datetime
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.firebase import identity
from app import volunteer_consent
from app.models import FcmUnregister
from test_volunteer import db, vol


def missing(db):
    for key in ('terms_version', 'privacy_version', 'terms_accepted_at', 'privacy_accepted_at'):
        db.data['users/one'].pop(key, None)


def body(**changes):
    return dict(accepted=True, terms_version=volunteer_consent.TERMS_VERSION,
                privacy_version=volunteer_consent.PRIVACY_VERSION, **changes)


def test_first_login_and_atomic_idempotent_server_acceptance(db):
    missing(db)
    before = dict(db.data['events/test-event/volunteers/one'])
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        profile = client.get('/v1/volunteer').json()
        assert profile['consent_current'] is False
        assert profile['event_id'] is None
        result = client.post('/v1/volunteer/consent', json=body())
        assert result.status_code == 200 and result.json()['consent_current'] is True
        saved = dict(db.data['users/one'])
        for field in ('terms_accepted_at', 'privacy_accepted_at'):
            assert isinstance(saved[field], datetime)
        assert saved['terms_version'] == saved['privacy_version'] == 'draft-2026-09'
        assert client.post('/v1/volunteer/consent', json=body()).status_code == 200
        assert db.data['users/one'] == saved
        assert client.get('/v1/volunteer').json()['consent_current'] is True
        assert client.get('/v1/volunteer/cases/available').status_code == 200
    assert db.data['events/test-event/volunteers/one'] == before
    assert 'location' not in saved


@pytest.mark.parametrize('method,path,payload', [
    ('GET', '/cases/available', None), ('GET', '/cases/mine', None),
    ('POST', '/cases/unknown/start-search', None),
    ('GET', '/profiles', None), ('GET', '/found-reports', None),
    ('GET', '/found-reports/unknown', None),
    ('POST', '/found-reports/manual', {'request_id': 'manual-no-consent-0001', 'profile_id': 'a'*64}),
    ('GET', '/notifications', None),
    ('PUT', '/notifications/unknown/read', None),
    ('GET', '/cases/unknown', None), ('GET', '/cases/unknown/state', None),
    ('GET', '/cases/unknown/photo', None),
    ('GET', '/profiles/' + 'a'*64, None),
    ('GET', '/profiles/' + 'a'*64 + '/photo', None),
    ('POST', '/found-reports', {'request_id': 'camera-no-consent-0001', 'photo_base64': 'not-an-image'}),
    ('GET', '/found-reports/unknown/photo', None),
    ('GET', '/found-reports/unknown/registered-photo', None),
    ('GET', '/found-reports/unknown/candidates', None),
    ('POST', '/found-reports/unknown/confirm-match', {'profile_id': 'a'*64}),
    ('POST', '/found-reports/unknown/begin-verification', None),
    ('POST', '/found-reports/unknown/verify', {'payload': 'not-a-qr'}),
    ('POST', '/found-reports/unknown/verify-identifier', {'identifier': 'FR-unknown'}),
    ('POST', '/found-reports/unknown/handover', None),
    ('POST', '/found-reports/unknown/end', None),
    ('PUT', '/fcm-registrations', {'token': 'test-token', 'locale': 'en'}),
])
def test_protected_routes_block_before_consent(db, method, path, payload):
    missing(db)
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    before = dict(db.data)
    with TestClient(app) as client:
        result = client.request(method, '/v1/volunteer' + path, json=payload)
        assert result.status_code == 403, result.text
        assert result.json()['detail'] == 'volunteer_consent_required'
    assert db.data == before


@pytest.mark.parametrize('changes,code', [
    ({'accepted': False}, 422), ({'accepted': 1}, 422), ({'terms_version': 'stale'}, 409),
    ({'privacy_version': 'future'}, 409),
    ({'terms_accepted_at': '2000-01-01'}, 422),
])
def test_rejects_false_stale_and_client_timestamps(db, changes, code):
    missing(db)
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    before = dict(db.data['users/one'])
    with TestClient(app) as client:
        assert client.post('/v1/volunteer/consent', json={**body(), **changes}).status_code == code
    assert db.data['users/one'] == before


def test_future_version_requires_reconsent_without_migration(db, monkeypatch):
    saved = dict(db.data['users/one'])
    monkeypatch.setattr(volunteer_consent, 'PRIVACY_VERSION', 'future-version')
    assert vol().profile(require_assignment=False, require_consent=False)['consent_current'] is False
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as error: vol().list()
    assert error.value.detail == 'volunteer_consent_required'
    vol().unregister_device(FcmUnregister(token='test-device'))
    assert db.data['users/one'] == saved


def test_acceptance_does_not_bypass_role_status_or_assignment(db):
    from fastapi import HTTPException
    missing(db)
    db.data.pop('events/test-event/volunteers/one')
    volunteer_consent.accept(vol(), volunteer_consent.ConsentInput(**body()))
    with pytest.raises(HTTPException) as error: vol().list()
    assert error.value.detail == 'event_access_required'
    db.data['users/one']['active'] = False
    with pytest.raises(HTTPException) as error:
        volunteer_consent.accept(vol(), volunteer_consent.ConsentInput(**body()))
    assert error.value.detail == 'volunteer_inactive'
    db.data['users/one']['role'] = 'guardian'
    with pytest.raises(HTTPException) as error:
        volunteer_consent.accept(vol(), volunteer_consent.ConsentInput(**body()))
    assert error.value.detail == 'volunteer_required'
