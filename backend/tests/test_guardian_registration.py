"""Firebase account-first lifecycle; real HTTP authorization, synthetic Auth only."""
import pytest

from app import firebase
from test_email_verification import api, PROFILE

HEADERS = {'Authorization': 'Bearer signed-token'}


def test_unverified_account_has_no_profile_and_cannot_create_one(api):
    client, db, token, record = api
    del db.data['users/guardian']
    before = dict(db.data)
    assert client.get('/v1/session', headers=HEADERS).status_code == 404
    assert client.put('/v1/guardian', json=PROFILE, headers=HEADERS).status_code == 403
    assert client.get('/v1/individuals', headers=HEADERS).status_code == 404
    assert db.data == before


@pytest.mark.parametrize('claim,live', [(False, True), (True, False), (None, True)])
def test_new_profile_cannot_bypass_signed_and_current_verification(api, claim, live):
    client, db, token, record = api
    del db.data['users/guardian']
    token['email_verified'], record.email_verified = claim, live
    before = dict(db.data)
    response = client.put('/v1/guardian', json=PROFILE, headers=HEADERS)
    assert response.status_code == 403
    assert response.json()['detail'] == 'email_verification_required'
    assert db.data == before


@pytest.mark.parametrize('uid', ['firebase-created-uid', 'previous-otp-created-uid'])
def test_verified_profile_creation_and_retry_preserve_firebase_uid_and_schema(api, uid):
    client, db, token, record = api
    del db.data['users/guardian']
    token['uid'], token['email_verified'], record.email_verified = uid, True, True
    response = client.put('/v1/guardian', json=PROFILE, headers=HEADERS)
    assert response.status_code == 200
    saved = dict(db.data[f'users/{uid}'])
    assert saved['full_name'] == PROFILE['full_name']
    assert saved['phone'] == PROFILE['phone']
    assert saved['role'] == 'guardian'
    assert {'created_at', 'age_confirmed_at', 'privacy_acknowledged_at',
            'privacy_notice_version', 'updated_at'} <= saved.keys()
    retry = client.put('/v1/guardian', json={**PROFILE, 'full_name': 'Do not overwrite'}, headers=HEADERS)
    assert retry.status_code == 200
    assert db.data[f'users/{uid}'] == saved
    assert [p for p in db.data if p.startswith('users/')] == [f'users/{uid}']
    assert client.get('/v1/session', headers=HEADERS).json() == {'role': 'guardian'}


@pytest.mark.parametrize('field', ['age_confirmed', 'privacy_accepted', 'full_name', 'phone'])
def test_verified_identity_does_not_skip_required_profile_data_or_consents(api, field):
    client, db, token, record = api
    del db.data['users/guardian']
    token['email_verified'] = record.email_verified = True
    body = dict(PROFILE)
    body[field] = False if field.endswith(('confirmed', 'accepted')) else ''
    before = dict(db.data)
    assert client.put('/v1/guardian', json=body, headers=HEADERS).status_code == 422
    assert db.data == before


def test_auth_unavailable_is_retryable_without_provisioning_or_profile_write(api, monkeypatch):
    client, db, token, record = api
    del db.data['users/guardian']
    token['email_verified'] = record.email_verified = True
    def offline(*args, **kwargs):
        raise ConnectionError('synthetic offline')
    monkeypatch.setattr(firebase.auth, 'get_user', offline)
    assert client.put('/v1/guardian', json=PROFILE, headers=HEADERS).status_code == 503
    assert 'users/guardian' not in db.data
    monkeypatch.setattr(firebase.auth, 'get_user', lambda *a, **k: record)
    assert client.put('/v1/guardian', json=PROFILE, headers=HEADERS).status_code == 200


@pytest.mark.parametrize('path', ['start', 'status', 'resend', 'confirm', 'cancel', 'complete'])
def test_obsolete_custom_registration_endpoints_are_not_available(api, path, monkeypatch):
    client, db, token, record = api
    def unexpected(*args, **kwargs):
        raise AssertionError('Removed registration must not provision or mutate any Auth account')
    for method in ['create_user', 'update_user', 'delete_user', 'revoke_refresh_tokens']:
        monkeypatch.setattr(firebase.auth, method, unexpected)
    before = dict(db.data)
    assert client.post(f'/v1/registration/{path}', json={}).status_code == 404
    assert db.data == before
