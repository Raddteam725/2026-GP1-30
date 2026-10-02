import os
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import delivery_queue, main
from test_dev_setup import runner

@pytest.fixture(autouse=True)
def clean_environment(monkeypatch):
    # setenv first so monkeypatch restores the original (unset) values afterwards.
    for name in ('K_SERVICE', 'RADD_LOCAL_JOBS', 'RADD_DELIVERY_MODE'):
        monkeypatch.setenv(name, '')
        monkeypatch.delenv(name)

@pytest.fixture
def local_jobs(monkeypatch):
    started = []
    class RecordingJobs:
        def start(self):
            started.append(self)
        def stop(self):
            pass
    monkeypatch.setattr(main, 'LocalJobs', RecordingJobs)
    return started

def test_configure_local_jobs_overrides_shell_value(monkeypatch, capsys):
    monkeypatch.setenv('RADD_LOCAL_JOBS', '1')
    runner.configure_local_jobs(False)
    assert os.environ['RADD_LOCAL_JOBS'] == '0'
    assert 'OFF' in capsys.readouterr().out
    runner.configure_local_jobs(True)
    assert os.environ['RADD_LOCAL_JOBS'] == '1'
    output = capsys.readouterr().out
    assert 'ON' in output and 'WARNING' in output

def test_parser_accepts_local_jobs_and_defaults_off():
    parser = runner.build_parser()
    assert parser.parse_args([]).local_jobs is False
    assert parser.parse_args(['--local-jobs']).local_jobs is True

def test_cloud_run_never_starts_local_jobs(monkeypatch, local_jobs):
    monkeypatch.setenv('K_SERVICE', 'radd-api')
    monkeypatch.setenv('RADD_LOCAL_JOBS', '1')
    with TestClient(main.app) as client:
        assert client.get('/health').status_code == 200
    assert local_jobs == []

def test_local_jobs_start_without_cloud_run(monkeypatch, local_jobs):
    monkeypatch.setenv('RADD_LOCAL_JOBS', '1')
    with TestClient(main.app):
        pass
    assert len(local_jobs) == 1

def test_delivery_mode_defaults_inline_on_cloud_run(monkeypatch):
    assert delivery_queue.delivery_mode() == 'queue'
    monkeypatch.setenv('K_SERVICE', 'radd-api')
    assert delivery_queue.delivery_mode() == 'inline'

def test_cloud_run_refuses_explicit_queue_mode(monkeypatch, local_jobs):
    monkeypatch.setenv('K_SERVICE', 'radd-api')
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'queue')
    with pytest.raises(RuntimeError):
        with TestClient(main.app):
            pass
    assert local_jobs == []

def test_cloud_run_starts_with_inline_mode(monkeypatch, local_jobs):
    monkeypatch.setenv('K_SERVICE', 'radd-api')
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'inline')
    with TestClient(main.app) as client:
        assert client.get('/health').status_code == 200
    assert local_jobs == []
