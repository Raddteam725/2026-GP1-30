"""FastAPI AI startup checks use only synthetic inputs and fake dependencies."""
import asyncio
import sys
from types import SimpleNamespace

import pytest

from app import face_matching
from app.main import app, lifespan


class NoFace(Exception):
    pass


def fake_ai(monkeypatch, *, recognition=None, detector_error=None):
    """Mock heavy AI packages so unit tests never load TensorFlow or weights."""
    events = []
    embedding = ([1.0] + [0.0] * 511) if recognition is None else recognition

    def represent(**kw):
        events.append(('recognition', kw))
        return [{'embedding': embedding}]

    def extract_faces(**kw):
        events.append(('detector', kw))
        raise detector_error if detector_error is not None else NoFace('no face')

    model = SimpleNamespace(
        build_model=lambda model: events.append(('load', model)),
        represent=represent, extract_faces=extract_faces)
    monkeypatch.setitem(sys.modules, 'deepface', SimpleNamespace(DeepFace=model))
    monkeypatch.setitem(sys.modules, 'deepface.modules', SimpleNamespace())
    monkeypatch.setitem(sys.modules, 'deepface.modules.exceptions',
                        SimpleNamespace(FaceNotDetected=NoFace))
    monkeypatch.setitem(sys.modules, 'numpy', SimpleNamespace(
        full=lambda shape, fill_value, dtype: object(), uint8=object()))
    return events


def test_warm_up_invokes_recognition_then_real_detector(monkeypatch):
    events = fake_ai(monkeypatch)
    face_matching.DeepFaceEngine().warm_up()
    assert [event[0] for event in events] == ['load', 'recognition', 'detector']
    assert events[1][1]['model_name'] == 'Facenet512'
    assert events[1][1]['detector_backend'] == 'skip'
    assert events[1][1]['normalization'] == 'Facenet2018'
    assert events[2][1]['detector_backend'] == 'mtcnn'
    assert events[2][1]['enforce_detection'] is True


@pytest.mark.parametrize('embedding', [[], [0.0] * 512, [1.0] * 511,
                                       [float('nan')] + [0.0] * 511])
def test_warm_up_rejects_bad_recognition_embedding(monkeypatch, embedding):
    events = fake_ai(monkeypatch, recognition=embedding)
    with pytest.raises(face_matching.Unavailable):
        face_matching.DeepFaceEngine().warm_up()
    assert 'detector' not in [e[0] for e in events]


def test_warm_up_rejects_detector_initialization_error(monkeypatch):
    fake_ai(monkeypatch, detector_error=RuntimeError('mtcnn unavailable'))
    with pytest.raises(face_matching.Unavailable):
        face_matching.DeepFaceEngine().warm_up()


def test_disabled_ai_skips_warm_up(monkeypatch):
    monkeypatch.delenv('RADD_FACE_MATCHING', raising=False)
    monkeypatch.delenv('RADD_LOCAL_JOBS', raising=False)
    monkeypatch.setattr(face_matching, 'get_engine',
                        lambda: pytest.fail('must not load AI if disabled'))

    async def run():
        async with lifespan(app):
            pass
    asyncio.run(run())


def test_enabled_ai_warms_up_before_lifespan_yield(monkeypatch):
    monkeypatch.setenv('RADD_FACE_MATCHING', 'on')
    monkeypatch.delenv('RADD_LOCAL_JOBS', raising=False)
    events = []
    monkeypatch.setattr(face_matching, 'get_engine',
                        lambda: SimpleNamespace(warm_up=lambda: events.append('warm')))

    async def run():
        async with lifespan(app):
            events.append('ready')
    asyncio.run(run())
    assert events == ['warm', 'ready']


def test_enabled_ai_failure_stops_server_startup(monkeypatch):
    monkeypatch.setenv('RADD_FACE_MATCHING', 'on')
    monkeypatch.delenv('RADD_LOCAL_JOBS', raising=False)

    def fail():
        raise face_matching.Unavailable()
    monkeypatch.setattr(face_matching, 'get_engine',
                        lambda: SimpleNamespace(warm_up=fail))

    async def run():
        async with lifespan(app):
            pytest.fail('must not accept requests when enabled AI is unavailable')
    with pytest.raises(RuntimeError, match='AI startup check failed'):
        asyncio.run(run())
