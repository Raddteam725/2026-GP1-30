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


# --- The Guardian may change the retention period from the profile --------

def periods(db, *options):
    db.data['events/test-event']['registration_periods'] = [
        {'id': key, 'duration_hours': hours} for key, hours in options]


def test_retention_can_be_extended_and_shortened_from_the_original_start(storage):
    db, _ = storage
    periods(db, ('short', 2), ('day', 24), ('long', 72), ('week', 168))
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    started = ref.get().to_dict()['registration_started_at']
    assert ref.get().to_dict()['registration_period_id'] == 'week'  # longest by default
    # Extending is impossible here (week is the longest); shorten to a day.
    guardian.save(input(registration_period_id='day'), identifier)
    data = ref.get().to_dict()
    assert data['registration_started_at'] == started  # the start never moves
    assert data['registration_expires_at'] == started + timedelta(hours=24)
    assert data['registration_period_id'] == 'day' and data['registration_duration_hours'] == 24
    # Extend again, counted from the same start.
    guardian.save(input(registration_period_id='long'), identifier)
    assert ref.get().to_dict()['registration_expires_at'] == started + timedelta(hours=72)
    # A profile edit without a period leaves retention untouched; so does a new photo.
    renamed = IndividualInput(full_name='Renamed', age=7, gender='female', relationship='child', photo_base64=photo())
    guardian.save(renamed, identifier)
    assert ref.get().to_dict()['registration_expires_at'] == started + timedelta(hours=72)
    assert guardian.get(identifier).to_dict()['full_name'] == 'Renamed'


def test_shortening_to_an_already_passed_deadline_is_rejected(storage):
    db, _ = storage
    periods(db, ('short', 2), ('long', 72))
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    # Registered three days ago with the 72-hour option (still 1 minute left).
    started = datetime.now(timezone.utc) - timedelta(hours=72) + timedelta(minutes=1)
    ref.update({'registration_started_at': started, 'registration_expires_at': started + timedelta(hours=72)})
    with pytest.raises(HTTPException) as error:
        guardian.save(input(registration_period_id='short'), identifier)  # would have ended 70 h ago
    assert error.value.status_code == 409 and error.value.detail == 'retention_deadline_passed'
    assert ref.get().to_dict()['registration_period_id'] == 'long'
    options = guardian.retention_options(identifier)
    # Every configured option is listed with its deadline; the passed one is
    # marked unavailable so the app can show it disabled.
    assert [(o['id'], o['available'], o['reason']) for o in options['options']] == [
        ('short', False, 'deadline_passed'), ('long', True, None)]
    assert options['options'][0]['expires_at'] == started + timedelta(hours=2)
    assert options['current_period_id'] == 'long' and options['editable'] is True


def test_retention_cannot_exceed_the_event_end_or_use_an_unknown_option(storage):
    db, _ = storage
    periods(db, ('short', 2), ('long', 72), ('week', 168))
    db.data['events/test-event']['ends_at'] = datetime.now(timezone.utc) + timedelta(hours=100)
    guardian, identifier = guardian_with_individual('owner')  # longest that fits: long
    assert guardian.get(identifier).to_dict()['registration_period_id'] == 'long'
    for option in ('week', 'never-configured'):
        with pytest.raises(HTTPException) as error:
            guardian.save(input(registration_period_id=option), identifier)
        assert error.value.status_code == 422 and error.value.detail == 'invalid_registration_period'
    assert [(o['id'], o['available'], o['reason']) for o in guardian.retention_options(identifier)['options']] == [
        ('short', True, None), ('long', True, None), ('week', False, 'beyond_event')]
    # Extending the event afterwards makes the week option reachable, still from the original start.
    db.data['events/test-event']['ends_at'] = datetime.now(timezone.utc) + timedelta(days=30)
    guardian.save(input(registration_period_id='week'), identifier)
    data = guardian.get(identifier).to_dict()
    assert data['registration_expires_at'] == data['registration_started_at'] + timedelta(hours=168)


def test_retention_edit_keeps_the_existing_profile_restrictions(storage):
    db, _ = storage
    periods(db, ('short', 2), ('long', 72))
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    CaseService(guardian).create(CaseCreate(individual_id=identifier))
    with pytest.raises(HTTPException) as error:  # locked like every other edit
        guardian.save(input(registration_period_id='short'), identifier)
    assert error.value.status_code == 409 and error.value.detail == 'active_case'
    assert guardian.retention_options(identifier)['editable'] is False
    db.data['cases/' + [p for p in db.data if p.startswith('cases/')][0].split('/')[1]]['status'] = 'resolved'
    ref.update({'active_case_id': None})
    expire(db, ref)  # an expired registration cannot be revived by choosing a longer period
    with pytest.raises(HTTPException) as error:
        guardian.save(input(registration_period_id='long'), identifier)
    assert error.value.status_code == 409 and error.value.detail == 'registration_unavailable'
    with pytest.raises(HTTPException):
        guardian.retention_options(identifier)
    # Another Guardian never reaches it.
    from test_crud import guardian as other_guardian
    with pytest.raises(HTTPException) as error:
        other_guardian('intruder').retention_options(identifier)
    assert error.value.status_code == 404


def test_cleanup_deletes_at_the_updated_deadline(storage):
    db, bucket = storage
    periods(db, ('short', 2), ('long', 72))
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    # Registered 1.5 hours ago with 72 h; shorten to 2 h -> 30 minutes left.
    started = datetime.now(timezone.utc) - timedelta(hours=1, minutes=30)
    ref.update({'registration_started_at': started, 'registration_expires_at': started + timedelta(hours=72)})
    guardian.save(input(registration_period_id='short'), identifier)
    expire_photos()
    assert ref.get().exists  # not yet due
    ref.update({'registration_started_at': started - timedelta(hours=1)})  # simulate time passing
    ref.update({'registration_expires_at': ref.get().to_dict()['registration_started_at'] + timedelta(hours=2)})
    assert guardian.list()[0]['photo_expired'] is True
    expire_photos(); expire_photos()
    assert not ref.get().exists and not bucket.data


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


# --- Registered photo replacement: one current photo, retention untouched --

def test_replacement_keeps_one_current_photo_and_never_touches_retention(storage):
    db, bucket = storage
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    before = ref.get().to_dict()
    old_path = before['photo_path']
    assert list(bucket.data) == [old_path]
    guardian.save(input(photo_base64=photo()), identifier)
    after = ref.get().to_dict()
    # A new object became the current photo; the superseded one is gone.
    assert after['photo_path'] != old_path and after['photo_path'].startswith(f'guardians/owner/individuals/{identifier}/')
    assert list(bucket.data) == [after['photo_path']]
    assert guardian.photo(identifier) == bucket.data[after['photo_path']]
    # Retention is a separate concern: start, choice and deadline are identical.
    for field in ('registration_started_at', 'registration_expires_at', 'registration_period_id',
                  'registration_duration_hours', 'event_id'):
        assert after[field] == before[field], field
    assert after['photo_captured_at'] >= before['photo_captured_at']  # metadata only, never a deadline
    assert not [p for p in db.data if p.startswith('photo_cleanup/')]


def test_failed_replacement_keeps_the_existing_photo_and_removes_the_upload(storage):
    db, bucket = storage
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    old_path = ref.get().to_dict()['photo_path']
    # The record becomes locked (a case is reported) between the upload and
    # the transaction: the replacement must fail closed.
    db.update(ref, {'active_case_id': 'RD-LOCKED'})
    with pytest.raises(HTTPException) as error:
        guardian.save(input(photo_base64=photo()), identifier)
    assert error.value.status_code == 409 and error.value.detail == 'active_case'
    assert ref.get().to_dict()['photo_path'] == old_path
    assert list(bucket.data) == [old_path]  # the new upload was removed, the valid photo survives


def test_superseded_photo_deletion_failure_is_queued_and_drained(storage):
    from app.cleanup import run as drain_cleanup
    db, bucket = storage
    guardian, identifier = guardian_with_individual('owner')
    ref = guardian.get(identifier).reference
    old_path = ref.get().to_dict()['photo_path']
    bucket.fail_next_delete(old_path)
    guardian.save(input(photo_base64=photo()), identifier)
    new_path = ref.get().to_dict()['photo_path']
    assert new_path != old_path and old_path in bucket.data  # not lost silently...
    queued = [d for p, d in db.data.items() if p.startswith('photo_cleanup/')]
    assert [d['path'] for d in queued] == [old_path]  # ...but queued for retry
    drain_cleanup()
    assert list(bucket.data) == [new_path]
    assert not [p for p in db.data if p.startswith('photo_cleanup/')]
