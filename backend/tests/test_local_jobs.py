import sys
from pathlib import Path
from unittest.mock import Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import local_jobs, cleanup, jobs
from test_volunteer import db, vol, case
from test_volunteer_workflow import submit, photos


def test_local_jobs_are_one_minute_and_failure_does_not_skip_other_jobs(monkeypatch):
    assert local_jobs.INTERVAL_SECONDS == 60
    calls = []
    def broken():
        calls.append('queue')
        raise OSError('offline')
    monkeypatch.setattr(cleanup, 'run', broken)
    monkeypatch.setattr(cleanup, 'expire_photos', lambda: calls.append('photos'))
    monkeypatch.setattr(cleanup, 'scrub_terminal_cases', lambda: calls.append('cases'))
    monkeypatch.setattr(cleanup, 'delete_finished_found_photos', lambda: calls.append('found'))
    monkeypatch.setattr(jobs, 'retry_alerts', lambda: calls.append('alerts'))
    monkeypatch.setattr(jobs, 'retry_guardian_alerts', lambda: calls.append('guardian'))
    local_jobs.run_once()
    assert calls == ['queue', 'photos', 'cases', 'found', 'alerts', 'guardian']


def test_finished_photo_retry_does_not_delete_active_attempt_or_change_case(db, monkeypatch, photos):
    from app import service
    monkeypatch.setattr(cleanup, 'database', lambda: db)
    monkeypatch.setattr(cleanup, 'bucket', service.bucket)
    _, identifier = case()
    active = submit(request_id='active-report-request')
    ended = submit(request_id='ended-report-request')
    ended_ref = db.collection('found_reports').document(ended['id'])
    ended_ref.update({'ended': True})
    before = dict(db.data['cases/' + identifier])
    cleanup.delete_finished_found_photos()
    assert 'photo_path' not in ended_ref.get().to_dict()
    assert vol().found_photo(active['id'])
    assert db.data['cases/' + identifier] == before


def test_retry_dispatches_existing_cases_without_creating_new_records(db, monkeypatch):
    _, identifier = case()
    monkeypatch.setattr(jobs, 'database', lambda: db)
    dispatch = Mock()
    monkeypatch.setattr(jobs, 'dispatch', dispatch)
    jobs.retry_alerts()
    dispatch.assert_called_once_with(db, identifier, matched=False)
