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


def test_top_k_comes_from_settings(monkeypatch):
    monkeypatch.setenv('RADD_MATCH_TOP_K', '3')
    assert face_matching.top_k() == 3
    monkeypatch.delenv('RADD_MATCH_TOP_K')
    assert face_matching.top_k() == 5


@pytest.mark.parametrize('age,rule', [(0, (0.65, 0.45, 0.25)), (2, (0.65, 0.45, 0.25)),
                                      (3, (0.60, 0.45, 0.15)), (5, (0.60, 0.45, 0.15)),
                                      (6, (0.38, None, None)), (17, (0.38, None, None)),
                                      (18, (0.30, None, None)), (59, (0.30, None, None)),
                                      (60, (0.38, None, None)), (130, (0.38, None, None)),
                                      (None, (0.38, None, None)), ('7', (0.38, None, None)),
                                      (-1, (0.38, None, None)), (True, (0.38, None, None))])
def test_rule_depends_on_registered_age(age, rule):
    assert face_matching.rule_for_age(age) == rule


def test_age_rules_can_be_overridden(monkeypatch):
    monkeypatch.setenv('RADD_MATCH_RULES', '[[17, 0.5, null, null], [200, 0.4, 0.3, 0.1]]')
    assert face_matching.rule_for_age(10) == (0.5, None, None)
    assert face_matching.rule_for_age(40) == (0.4, 0.3, 0.1)


def scored(similarity, second=0.0):
    """Unit probe and embeddings with the given cosine similarities to it."""
    return unit(1, 0, 0), unit(similarity, math.sqrt(1 - similarity ** 2), 0), \
        unit(second, 0, math.sqrt(1 - second ** 2))


def test_search_uses_the_age_threshold():
    probe, e, _ = scored(0.33)
    assert face_matching.search(probe, [('adult', e, 30, False)]) == [('adult', pytest.approx(0.33))]
    assert face_matching.search(probe, [('child', e, 9, False)]) == []


def test_clear_winner_rule_for_young_children():
    probe, toddler, other = scored(0.50, second=0.30)   # below 0.60, but 0.20 ahead of the next person
    assert [i for i, _ in face_matching.search(probe, [('t', toddler, 3, False), ('o', other, 9, False)])] == ['t']
    probe, toddler, other = scored(0.50, second=0.40)   # only 0.10 ahead: not a clear winner
    assert face_matching.search(probe, [('t', toddler, 3, False), ('o', other, 30, False)]) == [('o', pytest.approx(0.40))]
    probe, baby, other = scored(0.50, second=0.30)      # babies need a 0.25 gap
    assert face_matching.search(probe, [('b', baby, 1, False), ('o', other, 9, False)]) == []
    probe, toddler, _ = scored(0.44)                    # below the 0.45 floor
    assert face_matching.search(probe, [('t', toddler, 4, False)]) == []


def test_open_cases_first_without_hiding_a_better_match():
    probe = unit(1, 0, 0, 0)
    def at(s, axis):
        v = [s, 0, 0, 0]
        v[axis] = math.sqrt(1 - s * s)
        return unit(*v)
    gallery = [('open', at(0.70, 1), 30, True), ('higher', at(0.90, 2), 30, False),
               ('lower', at(0.50, 3), 30, False)]
    # 'lower' passes the adult threshold too, but is hidden behind the open case; 'higher' is not.
    assert [i for i, _ in face_matching.search(probe, gallery)] == ['higher', 'open']
    # Without an open case shown, everyone eligible who passes is shown, best first.
    gallery[0] = ('open', at(0.10, 1), 30, True)
    assert [i for i, _ in face_matching.search(probe, gallery)] == ['higher', 'lower']


def test_search_skips_invalid_embeddings_and_applies_limit():
    probe = unit(1)
    gallery = [('bad', None, 30, False), ('nan', [float('nan')] * SIZE, 30, False)] + \
              [(f'p{i}', unit(1, i * 0.01), 30, False) for i in range(8)]
    assert [i for i, _ in face_matching.search(probe, gallery, limit=3)] == ['p0', 'p1', 'p2']


def test_matching_can_be_switched_off(monkeypatch):
    monkeypatch.delenv('RADD_FACE_MATCHING', raising=False)
    assert REAL_GET_ENGINE() is None
    monkeypatch.setenv('RADD_FACE_MATCHING', 'off')
    assert REAL_GET_ENGINE() is None


@pytest.fixture
def ai_modules(monkeypatch, tmp_path):
    """Fake onnxruntime and MTCNN modules and a fake model file; no real AI package or weights."""
    state = SimpleNamespace(output=[3.0] + [0.0] * (SIZE - 1), faces=[], inputs=[], detector_error=None,
                            session_error=None, detected=[])

    class Session:
        def __init__(self, path, providers):
            if state.session_error:
                raise state.session_error
            state.path = path

        def get_inputs(self):
            return [SimpleNamespace(name='input.1')]

        def run(self, outputs, feed):
            state.inputs.append(feed['input.1'])
            return [[state.output]]

    class MTCNN:
        def detect_faces(self, image):
            state.detected.append(image)
            if state.detector_error:
                raise state.detector_error
            return state.faces

    model = tmp_path / 'w600k_r50.onnx'
    model.write_bytes(b'not a real model')
    monkeypatch.setenv('RADD_FACE_MODEL_PATH', str(model))
    monkeypatch.setitem(sys.modules, 'onnxruntime', SimpleNamespace(InferenceSession=Session))
    monkeypatch.setitem(sys.modules, 'mtcnn', SimpleNamespace(MTCNN=MTCNN))
    return state


def real_engine(monkeypatch):
    monkeypatch.setenv('RADD_FACE_MATCHING', 'on')
    monkeypatch.setattr(face_matching, '_engine', None)
    return REAL_GET_ENGINE()


def face(x, y, w, h):
    return dict(box=[x, y, w, h], keypoints=dict(
        left_eye=(x + 0.3 * w, y + 0.4 * h), right_eye=(x + 0.7 * w, y + 0.4 * h), nose=(x + 0.5 * w, y + 0.6 * h),
        mouth_left=(x + 0.35 * w, y + 0.8 * h), mouth_right=(x + 0.65 * w, y + 0.8 * h)))


@pytest.mark.parametrize('package', ['onnxruntime', 'mtcnn'])
def test_enabled_missing_package_raises_when_embedding(monkeypatch, ai_modules, package):
    pytest.importorskip('numpy')
    monkeypatch.setitem(sys.modules, package, None)
    engine = real_engine(monkeypatch)
    assert isinstance(engine, face_matching.ArcFaceEngine)
    assert REAL_GET_ENGINE() is engine
    with pytest.raises(face_matching.Unavailable):
        engine.embed(service.normalize_photo(photo()))


def test_missing_model_file_is_unavailable(monkeypatch, ai_modules, tmp_path):
    pytest.importorskip('numpy')
    monkeypatch.setenv('RADD_FACE_MODEL_PATH', str(tmp_path / 'missing.onnx'))
    with pytest.raises(face_matching.Unavailable):
        real_engine(monkeypatch).embed(service.normalize_photo(photo()))


def test_model_loading_failure_is_unavailable(monkeypatch, ai_modules):
    pytest.importorskip('numpy')
    ai_modules.session_error = RuntimeError('onnx load')
    with pytest.raises(face_matching.Unavailable):
        real_engine(monkeypatch).embed(service.normalize_photo(photo()))


def test_no_face_is_distinct_from_detector_failure(monkeypatch, ai_modules):
    pytest.importorskip('numpy')
    pytest.importorskip('cv2')
    engine = real_engine(monkeypatch)
    assert engine.embed(service.normalize_photo(photo())) is None
    assert ai_modules.inputs == []
    ai_modules.detector_error = RuntimeError('mtcnn')
    with pytest.raises(face_matching.Unavailable):
        engine.embed(service.normalize_photo(photo()))


def test_engine_aligns_largest_face_and_normalizes(monkeypatch, ai_modules):
    np = pytest.importorskip('numpy')
    pytest.importorskip('cv2')
    ai_modules.faces = [face(2, 2, 6, 6), face(10, 10, 40, 40)]
    engine = real_engine(monkeypatch)
    assert engine.embed(service.normalize_photo(photo())) == unit(1)
    x = ai_modules.inputs[0]
    assert x.shape == (1, 3, 112, 112) and x.dtype == np.float32
    assert -1.0 <= float(x.min()) and float(x.max()) <= 1.0


def test_alignment_maps_landmarks_onto_the_template():
    np = pytest.importorskip('numpy')
    template = np.array(face_matching.ARCFACE_TEMPLATE)
    angle = np.deg2rad(15)
    rot = np.array([[np.cos(angle), -np.sin(angle)], [np.sin(angle), np.cos(angle)]])
    points = template @ rot.T * 2.5 + [40, 70]
    m = face_matching.similarity_transform(points)
    assert np.allclose(points @ m[:, :2].T + m[:, 2], template, atol=1e-6)


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


@pytest.mark.parametrize('score,shown', [(0.35, False), (0.40, True)])
def test_candidates_follow_the_registered_age_rule(db, monkeypatch, score, shown):
    register(db, 'guardian-a', unit(score, math.sqrt(1 - score ** 2)))  # registered age 7: threshold 0.38
    use_engine(monkeypatch, unit(1, 0))
    result = vol().candidates(submit()['id'])
    assert result['state'] == ('candidates' if shown else 'no_reliable_candidate')


def test_previous_model_embeddings_are_never_compared(db, monkeypatch):
    path = register(db, 'guardian-a', None)
    db.data[path]['face_embedding'] = unit(1, 0)  # a Facenet512-era field
    use_engine(monkeypatch, unit(1, 0))
    assert vol().candidates(submit()['id']) == {'state': 'no_reliable_candidate', 'candidates': []}


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
        monkeypatch.setitem(sys.modules, 'onnxruntime', None)
    else:
        monkeypatch.delenv('RADD_FACE_MATCHING', raising=False)
    if enabled:
        # Enabled AI that cannot load must now fail before accepting requests.
        with pytest.raises(RuntimeError, match='AI startup check failed'):
            with TestClient(app):
                pass
        return
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
