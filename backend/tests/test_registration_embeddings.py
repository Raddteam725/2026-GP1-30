"""Registration AI integration with isolated Firebase and fake engines only."""
import copy
import sys
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from app import face_matching, service
from app.main import app
from app.firebase import identity
from app.models import IndividualInput
from test_crud import storage, guardian, photo
from test_face_matching import unit, use_engine, REAL_GET_ENGINE, ai_modules


def value(with_photo=True):
    return IndividualInput(full_name='Test Person', age=7, gender='female',
                           relationship='child', photo_base64=photo() if with_photo else None)


@pytest.mark.parametrize('embedding', [unit(1), None])
def test_registration_embeds_normalized_photo_once_before_upload_and_transaction(
        storage, monkeypatch, embedding):
    db, bucket = storage
    owner = guardian('owner')
    engine = use_engine(monkeypatch, embedding)
    embed = engine.embed
    state = {'transaction': False, 'attempts': 0}
    def checked(content):
        assert not state['transaction'] and not bucket.data
        assert content == service.normalize_photo(photo())
        assert content.startswith(b'\xff\xd8')
        return embed(content)
    engine.embed = checked
    class NoWrites:
        def set(self, *args, **kwargs):
            pass
    def retry(fn):
        def run(tx):
            state['transaction'] = True
            try:
                state['attempts'] += 1
                fn(NoWrites())  # discarded attempt: Firestore may retry the callback
                state['attempts'] += 1
                return fn(tx)
            finally:
                state['transaction'] = False
        return run
    monkeypatch.setattr(service.firestore, 'transactional', retry)
    created = owner.save(value())
    stored = owner.get(created['id']).to_dict()
    assert stored[face_matching.EMBEDDING_FIELD] == embedding
    assert engine.calls == 1 and state['attempts'] == 2
    assert bucket.data[stored['photo_path']] == service.normalize_photo(photo())
    assert face_matching.EMBEDDING_FIELD not in created


@pytest.mark.parametrize('embedding', [unit(0, 1), None, 'disabled'])
def test_replacement_atomically_replaces_clears_or_removes_embedding(storage, monkeypatch, embedding):
    db, bucket = storage
    owner = guardian('owner')
    created = owner.save(value())
    ref = owner.get(created['id']).reference
    old = ref.get().to_dict()
    legacy_path = old['photo_path'] + '.embedding'
    bucket.data[legacy_path] = b'legacy fixture'
    ref.update({face_matching.EMBEDDING_FIELD: unit(1), 'embedding_path': legacy_path})
    if embedding == 'disabled':
        monkeypatch.setattr(face_matching, 'get_engine', lambda: None)
    else:
        use_engine(monkeypatch, embedding)
    writes = []
    original_set = db.set
    def capture(reference, data, merge=False):
        if reference.path == ref.path:
            writes.append(dict(data))
        return original_set(reference, data, merge)
    monkeypatch.setattr(db, 'set', capture)
    owner.save(value(), created['id'])
    current = ref.get().to_dict()
    assert len(writes) == 1
    assert writes[0]['photo_path'] == current['photo_path'] != old['photo_path']
    assert face_matching.EMBEDDING_FIELD in writes[0]
    if embedding == 'disabled':
        assert face_matching.EMBEDDING_FIELD not in current
    else:
        assert current[face_matching.EMBEDDING_FIELD] == embedding
    assert current['registration_expires_at'] == old['registration_expires_at']
    assert current['registration_started_at'] == old['registration_started_at']
    assert old['photo_path'] not in bucket.data and legacy_path not in bucket.data
    assert 'embedding_path' not in current and len(bucket.data) == 1


@pytest.mark.parametrize('setting', [None, 'off'])
def test_disabled_registration_omits_embedding(storage, monkeypatch, setting):
    if setting is None:
        monkeypatch.delenv('RADD_FACE_MATCHING', raising=False)
    else:
        monkeypatch.setenv('RADD_FACE_MATCHING', setting)
    monkeypatch.setattr(face_matching, 'get_engine', REAL_GET_ENGINE)
    owner = guardian('owner')
    created = owner.save(value())
    assert face_matching.EMBEDDING_FIELD not in owner.get(created['id']).to_dict()


@pytest.mark.parametrize('existing_embedding', [unit(1), None, 'missing'])
def test_details_only_edit_preserves_embedding_without_calling_ai(storage, monkeypatch, existing_embedding):
    owner = guardian('owner')
    created = owner.save(value())
    ref = owner.get(created['id']).reference
    if existing_embedding != 'missing':
        ref.update({face_matching.EMBEDDING_FIELD: existing_embedding})
    before = ref.get().to_dict()
    def never():
        pytest.fail('Detail-only edits must not request an engine')
    monkeypatch.setattr(face_matching, 'get_engine', never)
    owner.save(value(False).model_copy(update={'full_name': 'Edited Person'}), created['id'])
    after = ref.get().to_dict()
    assert after['full_name'] == 'Edited Person'
    for field in ('photo_path', 'registration_expires_at', face_matching.EMBEDDING_FIELD):
        assert (field in before) == (field in after)
        assert before.get(field) == after.get(field)


@pytest.mark.parametrize('replacement', [False, True])
@pytest.mark.parametrize('failure', ['engine', 'missing_dependency'])
def test_unavailable_ai_returns_http_503_without_saved_data_or_orphan_photo(
        storage, monkeypatch, ai_modules, replacement, failure):
    db, bucket = storage
    owner = guardian('owner')
    item_id = None
    if replacement:
        item_id = owner.save(value())['id']
        owner.get(item_id).reference.update({face_matching.EMBEDDING_FIELD: unit(1)})
    before_db, before_photos = copy.deepcopy(db.data), dict(bucket.data)
    if failure == 'engine':
        use_engine(monkeypatch, 'unavailable')
    else:
        monkeypatch.setenv('RADD_FACE_MATCHING', 'on')
        monkeypatch.setattr(face_matching, '_engine', None)
        monkeypatch.setattr(face_matching, 'get_engine', REAL_GET_ENGINE)
        monkeypatch.setitem(sys.modules, 'deepface', None)
    app.dependency_overrides[identity] = lambda: {'uid': 'owner'}
    try:
        with TestClient(app) as client:
            response = (client.put(f'/v1/individuals/{item_id}', json=value().model_dump())
                        if replacement else client.post('/v1/individuals', json=value().model_dump()))
        assert response.status_code == 503
        assert response.json() == {'detail': 'face_matching_unavailable'}
        assert db.data == before_db and bucket.data == before_photos
    finally:
        app.dependency_overrides.clear()


def test_concurrent_case_creation_still_blocks_replace_and_cleans_uploaded_photo(storage, monkeypatch):
    db, bucket = storage
    owner = guardian('owner')
    item_id = owner.save(value())['id']
    ref = owner.get(item_id).reference
    ref.update({face_matching.EMBEDDING_FIELD: unit(1)})
    old = ref.get().to_dict()
    def concurrent(fn):
        def run(tx):
            ref.update({'active_case_id': 'case-created-during-inference'})
            return fn(tx)
        return run
    monkeypatch.setattr(service.firestore, 'transactional', concurrent)
    use_engine(monkeypatch, unit(0, 1))
    with pytest.raises(HTTPException) as error:
        owner.save(value(), item_id)
    assert error.value.status_code == 409
    current = ref.get().to_dict()
    assert current['photo_path'] == old['photo_path']
    assert current[face_matching.EMBEDDING_FIELD] == old[face_matching.EMBEDDING_FIELD]
    assert list(bucket.data) == [old['photo_path']]


def test_guardian_api_never_exposes_embeddings(storage, monkeypatch):
    guardian('owner')
    use_engine(monkeypatch, unit(1))
    app.dependency_overrides[identity] = lambda: {'uid': 'owner'}
    try:
        with TestClient(app) as client:
            created = client.post('/v1/individuals', json=value().model_dump())
            assert created.status_code == 201
            item_id = created.json()['id']
            responses = [created, client.get('/v1/individuals'),
                         client.get(f'/v1/individuals/{item_id}'),
                         client.put(f'/v1/individuals/{item_id}', json=value(False).model_dump()),
                         client.put(f'/v1/individuals/{item_id}', json=value().model_dump())]
        for response in responses:
            assert response.status_code == (201 if response is created else 200)
            assert 'face_embedding' not in response.text and 'photo_path' not in response.text
    finally:
        app.dependency_overrides.clear()
