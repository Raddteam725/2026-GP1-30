import os
import sys
from pathlib import Path
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import jobs, cleanup

RETRY = ['alerts', 'guardian']
CLEANUP = ['queue', 'photos', 'cases', 'found']

@pytest.fixture
def calls(monkeypatch):
    calls = []
    def record(name):
        return lambda: calls.append(name)
    monkeypatch.setattr(jobs, 'retry_alerts', record('alerts'))
    monkeypatch.setattr(jobs, 'retry_guardian_alerts', record('guardian'))
    monkeypatch.setattr(cleanup, 'run', record('queue'))
    monkeypatch.setattr(cleanup, 'expire_photos', record('photos'))
    monkeypatch.setattr(cleanup, 'scrub_terminal_cases', record('cases'))
    monkeypatch.setattr(cleanup, 'delete_finished_found_photos', record('found'))
    return calls

@pytest.fixture
def mode(monkeypatch):
    # setenv first so monkeypatch restores the original (unset) value afterwards.
    monkeypatch.setenv('RADD_DELIVERY_MODE', '')
    monkeypatch.delenv('RADD_DELIVERY_MODE')

def test_run_retry_runs_only_retry_jobs_in_order(calls):
    assert jobs.run_retry() is True
    assert calls == RETRY

def test_run_cleanup_runs_only_cleanup_jobs_in_order(calls):
    assert jobs.run_cleanup() is True
    assert calls == CLEANUP

def test_failing_job_does_not_stop_the_others(calls, monkeypatch):
    def broken():
        calls.append('queue')
        raise OSError('offline')
    monkeypatch.setattr(cleanup, 'run', broken)
    assert jobs.run_cleanup() is False
    assert calls == CLEANUP

def test_main_retry_defaults_to_inline_delivery(calls, mode):
    assert jobs.main(['retry']) == 0
    assert os.environ['RADD_DELIVERY_MODE'] == 'inline'
    assert calls == RETRY

def test_main_refuses_queue_delivery_and_runs_nothing(calls, monkeypatch):
    monkeypatch.setenv('RADD_DELIVERY_MODE', 'queue')
    with pytest.raises(SystemExit) as exit_info:
        jobs.main(['cleanup'])
    assert exit_info.value.code not in (0, None)
    assert calls == []

def test_main_returns_1_when_a_job_fails(calls, mode, monkeypatch):
    def broken():
        calls.append('guardian')
        raise RuntimeError('boom')
    monkeypatch.setattr(jobs, 'retry_guardian_alerts', broken)
    assert jobs.main(['retry']) == 1
    assert calls == RETRY

def test_unknown_command_exits_2(calls, mode):
    with pytest.raises(SystemExit) as exit_info:
        jobs.main(['everything'])
    assert exit_info.value.code == 2
    assert calls == []
