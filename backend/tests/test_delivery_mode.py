import sys
import threading
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import delivery_queue
from app.main import app

# conftest replaces delivery_queue.submit per test; keep the real one.
real_submit = delivery_queue.submit

def test_default_and_empty_are_queue(monkeypatch):
    monkeypatch.delenv('RADD_DELIVERY_MODE', raising=False)
    assert delivery_queue.delivery_mode() == 'queue'
    monkeypatch.setenv('RADD_DELIVERY_MODE', '')
    assert delivery_queue.delivery_mode() == 'queue'

@pytest.mark.parametrize('mode', ['inline', 'queue'])
def test_valid_modes_are_accepted(monkeypatch, mode):
    monkeypatch.setenv('RADD_DELIVERY_MODE', mode)
    assert delivery_queue.delivery_mode() == mode

def test_invalid_mode_raises(monkeypatch):
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'background')
    with pytest.raises(ValueError):
        delivery_queue.delivery_mode()

def test_inline_runs_before_returning_without_threads(monkeypatch):
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'inline')
    started = []
    monkeypatch.setattr(threading.Thread, 'start', lambda self: started.append(self))
    ran = []
    assert real_submit('inline-run', lambda: ran.append(threading.current_thread())) is True
    assert ran == [threading.current_thread()]
    assert started == []

def test_inline_swallows_errors_and_keeps_working(monkeypatch):
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'inline')
    def fail():
        raise RuntimeError('boom')
    assert real_submit('inline-error', fail) is True
    ran = []
    assert real_submit('inline-error', lambda: ran.append(1)) is True
    assert ran == [1]

def test_inline_skips_key_already_in_progress(monkeypatch):
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'inline')
    calls = []
    def operation():
        calls.append(1)
        assert real_submit('inline-reentrant', operation) is True
    assert real_submit('inline-reentrant', operation) is True
    assert calls == [1]

def test_queue_mode_hands_work_to_dispatcher(monkeypatch):
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'queue')
    handed = []
    monkeypatch.setattr(delivery_queue.dispatcher, 'submit', lambda key, operation: handed.append((key, operation)) or True)
    operation = lambda: None
    assert real_submit('queued', operation) is True
    assert handed == [('queued', operation)]

def test_app_startup_fails_on_invalid_mode(monkeypatch):
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'background')
    with pytest.raises(ValueError):
        with TestClient(app):
            pass
