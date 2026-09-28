from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
import pytest
from fastapi import HTTPException
from app.models import IndividualInput
from app.registration_retention import establish, valid_periods, validate_configuration
from app.cleanup import expire_photos
from app.cases import CaseService
from app.case_models import CaseCreate, TERMINAL_STATUSES
from test_retention import storage
from test_cases import guardian_with_individual, photo


def input(**kw):
    return IndividualInput(full_name='Period Test', age=7, gender='female', relationship='child', **kw)


def expire(db, ref):
    ref.update({'registration_started_at': datetime.now(timezone.utc)-timedelta(days=5),
                'registration_expires_at': datetime.now(timezone.utc)-timedelta(seconds=1)})


def test_longest_period_is_default_and_expiry_is_explicit(storage):
    db, _ = storage
    guardian, identifier = guardian_with_individual('owner')
    data = guardian.get(identifier).to_dict()
    assert data['registration_period_id'] == 'long'
    assert data['registration_expires_at'] - data['registration_started_at'] == timedelta(hours=72)
    chosen = guardian.save(input(photo_base64=photo(), registration_period_id='short'))
    data = guardian.get(chosen['id']).to_dict()
    assert data['registration_expires_at'] - data['registration_started_at'] == timedelta(hours=2)


def test_event_end_filters_and_rejects_options(storage):
    db, _ = storage
    ref = db.collection('events').document('test-event')
    ref.update({'ends_at': datetime.now(timezone.utc)+timedelta(hours=4)})
    assert [p['id'] for p in valid_periods(ref.get())] == ['short']
    assert establish(ref.get())['registration_period_id'] == 'short'
    with pytest.raises(HTTPException): establish(ref.get(), 'long')
    ref.update({'ends_at': datetime.now(timezone.utc)+timedelta(minutes=1)})
    with pytest.raises(HTTPException): valid_periods(ref.get())


def test_capture_age_does_not_expire_valid_registration(storage):
    db, _ = storage
    guardian, identifier = guardian_with_individual('owner')
    guardian.get(identifier).reference.update({'photo_captured_at': datetime.now(timezone.utc)-timedelta(days=10)})
    assert guardian.list()[0]['photo_expired'] is False
    assert guardian.photo(identifier)
    assert CaseService(guardian).create(CaseCreate(individual_id=identifier))


def test_expiry_deletes_identifiable_profile_photo_embedding_not_account(storage):
    db, bucket = storage
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    old_photo = ref.get().to_dict()['photo_path']
    embedding = f'guardians/owner/individuals/{identifier}/face.bin'
    bucket.data[embedding] = b'fixture embedding'
    ref.update({'embedding_path': embedding, 'face_embedding': [1, 2]})
    expire(db, ref)
    with pytest.raises(HTTPException): guardian.photo(identifier)
    with pytest.raises(HTTPException): CaseService(guardian).create(CaseCreate(individual_id=identifier))
    expire_photos(); expire_photos()
    assert not ref.get().exists
    assert old_photo not in bucket.data and embedding not in bucket.data
    assert db.collection('users').document('owner').get().exists


@pytest.mark.parametrize('terminal', TERMINAL_STATUSES)
def test_deletion_deferred_until_terminal(storage, terminal):
    db, bucket = storage
    guardian, identifier = guardian_with_individual('owner')
    case_id = CaseService(guardian).create(CaseCreate(individual_id=identifier))['id']
    ref = guardian.get(identifier).reference
    expire(db, ref)
    expire_photos()
    assert ref.get().exists and guardian.photo(identifier)
    db.collection('cases').document(case_id).update({'status': terminal})
    expire_photos()
    assert not ref.get().exists
    assert db.collection('users').document('owner').get().exists
    assert 'guardian_id' not in db.data['cases/'+case_id]


def test_photo_replacement_and_event_extension_do_not_extend_registration(storage):
    db, _ = storage
    guardian, identifier = guardian_with_individual('owner')
    before = guardian.get(identifier).to_dict()
    guardian.save(input(photo_base64=photo()), identifier)
    assert guardian.get(identifier).to_dict()['registration_expires_at'] == before['registration_expires_at']
    event = db.collection('events').document('test-event')
    data = event.get().to_dict()
    extended = {**data, 'ends_at': data['ends_at']+timedelta(days=1)}
    validate_configuration(data, extended)
    event.update(extended)
    assert guardian.get(identifier).to_dict()['registration_expires_at'] == before['registration_expires_at']
    for field, value in [('starts_at', data['starts_at']-timedelta(days=1)), ('ends_at', data['ends_at']-timedelta(days=1))]:
        with pytest.raises(ValueError): validate_configuration(data, {**data, field: value})
    with pytest.raises(HTTPException): guardian.save(input(registration_period_id='short'), identifier)


def test_unknown_legacy_period_is_not_migrated_or_deleted(storage):
    db, _ = storage
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    for key in ['registration_started_at', 'registration_expires_at', 'registration_period_id', 'registration_duration_hours']:
        db.data[ref.path].pop(key)
    assert guardian.list()[0]['photo_expired'] is True
    before = dict(db.data[ref.path])
    expire_photos()
    assert db.data[ref.path] == before
    with pytest.raises(HTTPException): guardian.save(input(photo_base64=photo()), identifier)


def test_failed_storage_delete_keeps_reference_and_fence_for_retry(storage):
    db, bucket = storage
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    path = ref.get().to_dict()['photo_path']
    expire(db, ref)
    bucket.fail_next_delete(path)
    expire_photos()
    assert ref.get().to_dict()['deleting'] is True
    assert ref.get().to_dict()['photo_path'] == path
    expire_photos()
    assert not ref.get().exists


def test_missing_event_configuration_cannot_create_registration(storage):
    db, bucket = storage
    from test_crud import guardian
    owner = guardian('owner')
    db.collection('events').document('test-event').set({'active': True})
    with pytest.raises(HTTPException) as error:
        owner.save(input(photo_base64=photo()))
    assert error.value.detail == 'registration_configuration_required'
    assert not owner.list() and not bucket.data


def test_cleanup_never_deletes_unrelated_storage_or_case(storage):
    db, bucket = storage
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    expire(db, ref)
    ref.update({'embedding_path': 'guardians/someone-else/private.bin'})
    bucket.data['guardians/someone-else/private.bin'] = b'private'
    expire_photos()
    assert ref.get().exists
    assert bucket.data['guardians/someone-else/private.bin'] == b'private'


def test_period_endpoint_uses_authenticated_guardian_and_current_event(storage):
    from app.main import registration_periods
    from test_crud import guardian
    response = registration_periods(guardian('owner'))
    assert response['event_id'] == 'test-event'
    assert response['default_period_id'] == 'long'
    assert [option['duration_hours'] for option in response['options']] == [2, 72]
