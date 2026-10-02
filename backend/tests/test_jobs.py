import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import Mock
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import jobs, cleanup
from test_volunteer import db

real_retry_alerts = jobs.retry_alerts
LEASE = 'configuration/cleanup_lock'

RETRY = ['alerts', 'guardian']
CLEANUP = ['queue', 'photos', 'cases', 'found']

@pytest.fixture
def calls(monkeypatch, db):
    monkeypatch.setattr(jobs, 'database', lambda: db)
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

def other_lease(minutes):
    return {'owner': 'other', 'expires_at': datetime.now(timezone.utc) + timedelta(minutes=minutes)}

def test_cleanup_releases_lease_after_normal_run(calls, db):
    assert jobs.run_cleanup() is True
    assert calls == CLEANUP
    assert LEASE not in db.data

def test_cleanup_skips_while_another_owner_holds_unexpired_lease(calls, db):
    db.data[LEASE] = other_lease(10)
    before = dict(db.data[LEASE])
    assert jobs.run_cleanup() is True
    assert calls == []
    assert db.data[LEASE] == before

def test_cleanup_takes_over_expired_lease(calls, db):
    db.data[LEASE] = other_lease(-1)
    assert jobs.run_cleanup() is True
    assert calls == CLEANUP
    assert LEASE not in db.data

def test_release_does_not_delete_lease_replaced_by_another_owner(calls, db, monkeypatch):
    replaced = other_lease(10)
    def take_over():
        calls.append('photos')
        db.data[LEASE] = dict(replaced)
    monkeypatch.setattr(cleanup, 'expire_photos', take_over)
    assert jobs.run_cleanup() is True
    assert calls == CLEANUP
    assert db.data[LEASE] == replaced

def test_failing_cleanup_job_still_releases_lease(calls, db, monkeypatch):
    def broken():
        calls.append('queue')
        raise OSError('offline')
    monkeypatch.setattr(cleanup, 'run', broken)
    assert jobs.run_cleanup() is False
    assert calls == CLEANUP
    assert LEASE not in db.data

@pytest.mark.parametrize('target', ['database', 'acquire_cleanup_lease'])
def test_cleanup_runs_nothing_when_lease_cannot_be_acquired(calls, monkeypatch, target):
    def unavailable(*args):
        raise ConnectionError('offline')
    monkeypatch.setattr(jobs, target, unavailable)
    assert jobs.run_cleanup() is False
    assert calls == []

def test_retry_never_touches_cleanup_lease(calls, db, monkeypatch):
    db.data[LEASE] = other_lease(10)
    before = dict(db.data[LEASE])
    collections = []
    collection = db.collection
    monkeypatch.setattr(db, 'collection', lambda name: collections.append(name) or collection(name))
    monkeypatch.setattr(jobs, 'retry_alerts', real_retry_alerts)
    monkeypatch.setattr(jobs, 'dispatch', Mock())
    assert jobs.run_retry() is True
    assert 'events' in collections
    assert 'configuration' not in collections
    assert db.data[LEASE] == before
