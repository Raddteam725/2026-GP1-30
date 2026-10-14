"""Local maintenance jobs are opt-in (--local-jobs): cleanup deletes shared data."""
import os
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import main
from test_dev_setup import runner

@pytest.fixture(autouse=True)
def clean_environment(monkeypatch):
    monkeypatch.setenv('RADD_LOCAL_JOBS', '')
    monkeypatch.delenv('RADD_LOCAL_JOBS')

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

def test_server_without_opt_in_starts_no_local_jobs(local_jobs):
    with TestClient(main.app):
        pass
    assert local_jobs == []

def test_server_with_opt_in_starts_local_jobs(monkeypatch, local_jobs):
    monkeypatch.setenv('RADD_LOCAL_JOBS', '1')
    with TestClient(main.app):
        pass
    assert len(local_jobs) == 1
