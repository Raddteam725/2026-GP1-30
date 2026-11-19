"""FastAPI AI startup checks use only synthetic inputs and fake dependencies."""
import asyncio
import sys
from types import SimpleNamespace

import pytest

from app import face_matching
from app.main import app, lifespan


def fake_ai(monkeypatch, tmp_path, *, recognition=None, detector_error=None):
    """Fake onnxruntime and MTCNN so unit tests never load TensorFlow or weights."""
    pytest.importorskip('numpy')
    events = []
    output = ([1.0] + [0.0] * 511) if recognition is None else recognition

    class Session:
        def __init__(self, path, providers):
            events.append(('load', providers))

        def get_inputs(self):
            return [SimpleNamespace(name='input.1')]

        def run(self, outputs, feed):
            events.append(('recognition', feed['input.1'].shape))
            return [[output]]

    class MTCNN:
        def detect_faces(self, image):
            events.append(('detector', image.shape))
            if detector_error is not None:
                raise detector_error
            return []

    model = tmp_path / 'w600k_r50.onnx'
    model.write_bytes(b'fake')
    monkeypatch.setenv('RADD_FACE_MODEL_PATH', str(model))
    monkeypatch.setitem(sys.modules, 'onnxruntime', SimpleNamespace(InferenceSession=Session))
    monkeypatch.setitem(sys.modules, 'mtcnn', SimpleNamespace(MTCNN=MTCNN))
    return events


def test_warm_up_invokes_recognition_then_real_detector(monkeypatch, tmp_path):
    events = fake_ai(monkeypatch, tmp_path)
    face_matching.ArcFaceEngine().warm_up()
    assert [event[0] for event in events] == ['load', 'recognition', 'detector']
    assert events[0][1] == ['CPUExecutionProvider']
    assert events[1][1] == (1, 3, 112, 112)


@pytest.mark.parametrize('embedding', [[], [0.0] * 512, [1.0] * 511,
                                       [float('nan')] + [0.0] * 511])
def test_warm_up_rejects_bad_recognition_embedding(monkeypatch, tmp_path, embedding):
    events = fake_ai(monkeypatch, tmp_path, recognition=embedding)
    with pytest.raises(face_matching.Unavailable):
        face_matching.ArcFaceEngine().warm_up()
    assert 'detector' not in [e[0] for e in events]


def test_warm_up_rejects_detector_initialization_error(monkeypatch, tmp_path):
    fake_ai(monkeypatch, tmp_path, detector_error=RuntimeError('mtcnn unavailable'))
    with pytest.raises(face_matching.Unavailable):
        face_matching.ArcFaceEngine().warm_up()


def test_warm_up_rejects_missing_model_file(monkeypatch, tmp_path):
    fake_ai(monkeypatch, tmp_path)
    monkeypatch.setenv('RADD_FACE_MODEL_PATH', str(tmp_path / 'missing.onnx'))
    with pytest.raises(face_matching.Unavailable):
        face_matching.ArcFaceEngine().warm_up()


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
