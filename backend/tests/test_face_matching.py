"""Face matching (PBI 15/16) with a fake engine: no model, no real faces."""
import json
import math
import pytest
import sys
from types import SimpleNamespace
from fastapi.testclient import TestClient
from app.main import app
from app.firebase import identity
from app import face_matching, volunteer_workflow, service
from app.volunteer_workflow import FoundInput
from test_volunteer import db, vol
from test_cases import guardian_with_individual, photo

SIZE = face_matching.EMBEDDING_SIZE
REAL_GET_ENGINE = face_matching.get_engine  # captured before the conftest fixture replaces it


def unit(*values):
    v = list(values) + [0.0] * (SIZE - len(values))
    n = math.sqrt(sum(x * x for x in v))
    return [x / n for x in v]


class FakeEngine:
    def __init__(self, probe):
        self.probe = probe
        self.calls = 0

    def embed(self, image_bytes):
        self.calls += 1
        if self.probe == 'unavailable':
            raise face_matching.Unavailable()
        return self.probe


@pytest.fixture(autouse=True)
def photos(db, monkeypatch):
    monkeypatch.setattr(volunteer_workflow, 'bucket', service.bucket)


def use_engine(monkeypatch, probe):
    engine = FakeEngine(probe)
    monkeypatch.setattr(face_matching, 'get_engine', lambda: engine)
    return engine


def register(db, uid, embedding):
    guardian, person = guardian_with_individual(uid)
    path = guardian.user.collection('individuals').document(person).path
    if embedding is not None:
        db.data[path][face_matching.EMBEDDING_FIELD] = embedding
    return path


def submit():
    return vol().submit_found(FoundInput(request_id='request-00000000001', photo_base64=photo()))


# ---------- pure functions ----------
def test_match_ranks_best_first_applies_threshold_and_limit():
    probe = unit(1, 0)
    gallery = [('far', unit(0, 1)), ('close', unit(1, 0.1)), ('closest', unit(1, 0.01)), ('mid', unit(1, 1))]
    result = face_matching.match(probe, gallery, min_similarity=0.5, limit=2)
    assert [item for item, _ in result] == ['closest', 'close']
    assert all(s >= 0.5 for _, s in result)
    assert face_matching.match(probe, gallery, min_similarity=0.9999999, limit=5) == []


def test_invalid_or_missing_embeddings_are_skipped():
    probe = unit(1)
    bad = [None, [], [1.0] * 3, [float('nan')] + [0.0] * (SIZE - 1), 'text']
    gallery = [(i, b) for i, b in enumerate(bad)] + [('ok', unit(1))]
    assert [item for item, _ in face_matching.match(probe, gallery, min_similarity=0.0)] == ['ok']


def test_display_score_is_clipped_to_0_1():
    assert face_matching.display_score(-0.3) == 0.0
    assert face_matching.display_score(1.2) == 1.0
    assert face_matching.display_score(0.71234567) == 0.7123


def test_threshold_and_top_k_come_from_settings(monkeypatch):
    monkeypatch.setenv('RADD_MATCH_THRESHOLD', '0.7')
    monkeypatch.setenv('RADD_MATCH_TOP_K', '3')
    assert face_matching.threshold() == 0.7 and face_matching.top_k() == 3
    monkeypatch.delenv('RADD_MATCH_THRESHOLD')
    monkeypatch.delenv('RADD_MATCH_TOP_K')
    assert face_matching.threshold() == 0.596 and face_matching.top_k() == 5


def test_matching_can_be_switched_off(monkeypatch):
    monkeypatch.delenv('RADD_FACE_MATCHING', raising=False)
    assert REAL_GET_ENGINE() is None
    monkeypatch.setenv('RADD_FACE_MATCHING', 'off')
    assert REAL_GET_ENGINE() is None


@pytest.fixture
def ai_modules(monkeypatch):
    """Fake package imports and array conversion; never import any real AI package."""
    class Array:
        def __getitem__(self, index):
            return self
    class FaceNotDetected(ValueError):
        pass
    deepface = SimpleNamespace(build_model=lambda model: None, represent=lambda **kw: [])
    monkeypatch.setitem(sys.modules, 'numpy', SimpleNamespace(
        asarray=lambda image: Array(), ascontiguousarray=lambda array: array))
    monkeypatch.setitem(sys.modules, 'deepface', SimpleNamespace(DeepFace=deepface))
    monkeypatch.setitem(sys.modules, 'deepface.modules', SimpleNamespace())
    monkeypatch.setitem(sys.modules, 'deepface.modules.exceptions', SimpleNamespace(
        FaceNotDetected=FaceNotDetected))
    return deepface, FaceNotDetected


def real_engine(monkeypatch):
    monkeypatch.setenv('RADD_FACE_MATCHING', 'on')
    monkeypatch.setattr(face_matching, '_engine', None)
    return REAL_GET_ENGINE()


@pytest.mark.parametrize('package', ['numpy', 'deepface'])
def test_enabled_missing_package_raises_when_embedding(monkeypatch, ai_modules, package):
    monkeypatch.setitem(sys.modules, package, None)
    engine = real_engine(monkeypatch)
    assert isinstance(engine, face_matching.DeepFaceEngine)
    assert REAL_GET_ENGINE() is engine
    with pytest.raises(face_matching.Unavailable):
        engine.embed(service.normalize_photo(photo()))


@pytest.mark.parametrize('error', [ModuleNotFoundError('tensorflow'),
                                  ModuleNotFoundError('tf_keras'), ValueError('model loading')])
def test_model_loading_failure_is_unavailable(monkeypatch, ai_modules, error):
    def fail(model):
        raise error
    ai_modules[0].build_model = fail
    with pytest.raises(face_matching.Unavailable):
        real_engine(monkeypatch).embed(service.normalize_photo(photo()))


def test_no_face_exception_is_distinct_from_model_failure(monkeypatch, ai_modules):
    deepface, no_face = ai_modules
    engine = real_engine(monkeypatch)
    def fail(error):
        def represent(**kwargs):
            raise error
        deepface.represent = represent
    fail(no_face('no face'))
    assert engine.embed(service.normalize_photo(photo())) is None
    for error in (ValueError('detector loading'), RuntimeError('inference')):
        fail(error)
        with pytest.raises(face_matching.Unavailable):
            engine.embed(service.normalize_photo(photo()))


def test_engine_preserves_configuration_and_normalizes_largest_face(monkeypatch, ai_modules):
    deepface, _ = ai_modules
    models, options = [], []
    deepface.build_model = models.append
    def represent(**kwargs):
        options.append(kwargs)
        return [dict(facial_area=dict(w=1, h=1), embedding=[0, 2] + [0] * (SIZE - 2)),
                dict(facial_area=dict(w=2, h=2), embedding=[3] + [0] * (SIZE - 1))]
    deepface.represent = represent
    engine = real_engine(monkeypatch)
    assert engine.embed(service.normalize_photo(photo())) == unit(1)
    assert engine.embed(service.normalize_photo(photo())) == unit(1)
    assert models == ['Facenet512']
    assert all({k: v for k, v in o.items() if k != 'img_path'} == dict(
        model_name='Facenet512', detector_backend='mtcnn', enforce_detection=True,
        align=True, normalization='Facenet2018') for o in options)


# ---------- candidates endpoint ----------
def test_returns_ranked_candidates_without_exposing_embeddings(db, monkeypatch):
    register(db, 'guardian-a', unit(1, 0.05))
    register(db, 'guardian-b', unit(0, 1))
    use_engine(monkeypatch, unit(1, 0))
    report = submit()
    result = vol().candidates(report['id'])
    assert result['state'] == 'candidates'
    assert len(result['candidates']) == 1  # the unrelated person is below the threshold
    top = result['candidates'][0]
    assert 0 <= top['similarity'] <= 1 and top['similarity'] > 0.99
    assert top['person']['id'] in {p['id'] for p in vol().profiles_list()}
    text = json.dumps(result)
    assert 'face_embedding' not in text and 'photo_path' not in text and 'guardian_id' not in text


def test_no_reliable_candidate_when_nobody_is_similar_enough(db, monkeypatch):
    register(db, 'guardian-a', unit(0, 1))
    use_engine(monkeypatch, unit(1, 0))
    assert vol().candidates(submit()['id']) == {'state': 'no_reliable_candidate', 'candidates': []}


def test_no_face_in_found_photo_is_reported_as_no_reliable_candidate(db, monkeypatch):
    register(db, 'guardian-a', unit(1))
    use_engine(monkeypatch, None)
    result = vol().candidates(submit()['id'])
    assert result['state'] == 'no_reliable_candidate' and result['candidates'] == []
    assert result['reason'] == 'no_face_detected'


def test_registrations_without_embedding_are_not_ai_candidates_but_stay_listed(db, monkeypatch):
    register(db, 'guardian-a', None)  # e.g. no face detected at registration
    use_engine(monkeypatch, unit(1))
    assert vol().candidates(submit()['id'])['state'] == 'no_reliable_candidate'
    assert len(vol().profiles_list()) == 1  # still available for manual review


def test_registration_with_explicit_null_embedding_is_not_an_ai_candidate_but_stays_listed(db, monkeypatch):
    guardian, person = guardian_with_individual('guardian-a')
    ref = guardian.user.collection('individuals').document(person)
    ref.update({face_matching.EMBEDDING_FIELD: None})
    stored = ref.get().to_dict()
    assert face_matching.EMBEDDING_FIELD in stored
    assert stored[face_matching.EMBEDDING_FIELD] is None
    reviewer = vol()
    assert reviewer.eligible(ref.get())
    manual_profiles = reviewer.profiles_list()
    assert len(manual_profiles) == 1
    engine = use_engine(monkeypatch, unit(1))
    assert reviewer.candidates(submit()['id']) == {'state': 'no_reliable_candidate', 'candidates': []}
    assert engine.calls == 1
    assert reviewer.profiles_list() == manual_profiles


def test_model_failure_reports_unavailable_for_manual_review(db, monkeypatch):
    register(db, 'guardian-a', unit(1))
    use_engine(monkeypatch, 'unavailable')
    assert vol().candidates(submit()['id']) == {'state': 'unavailable', 'candidates': []}


@pytest.mark.parametrize('enabled', [False, True])
def test_candidates_endpoint_unavailable_when_disabled_or_dependencies_missing(
        db, monkeypatch, ai_modules, enabled):
    register(db, 'guardian-a', unit(1))
    report = submit()
    monkeypatch.setattr(face_matching, 'get_engine', REAL_GET_ENGINE)
    monkeypatch.setattr(face_matching, '_engine', None)
    if enabled:
        monkeypatch.setenv('RADD_FACE_MATCHING', 'on')
        monkeypatch.setitem(sys.modules, 'deepface', None)
    else:
        monkeypatch.delenv('RADD_FACE_MATCHING', raising=False)
    app.dependency_overrides[identity] = lambda: {'uid': 'one', 'role': 'volunteer'}
    with TestClient(app) as client:
        response = client.get(f"/v1/volunteer/found-reports/{report['id']}/candidates")
    assert response.status_code == 200
    assert response.json() == {'state': 'unavailable', 'candidates': []}


def test_other_event_registrations_are_never_candidates(db, monkeypatch):
    path = register(db, 'guardian-a', unit(1))
    db.data[path]['event_id'] = 'other-event'
    use_engine(monkeypatch, unit(1))
    assert vol().candidates(submit()['id'])['state'] == 'no_reliable_candidate'


def test_ended_identification_does_not_run_the_model(db, monkeypatch):
    register(db, 'guardian-a', unit(1))
    engine = use_engine(monkeypatch, unit(1))
    report = submit()
    vol().end_identification(report['id'])
    with pytest.raises(Exception):
        vol().candidates(report['id'])
    assert engine.calls == 0
