import sys
from pathlib import Path
from unittest.mock import Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import local_jobs, cleanup, jobs
from test_volunteer import db, vol, case
from test_volunteer_workflow import submit, photos


def test_local_jobs_are_one_minute_and_failure_does_not_skip_other_jobs(db, monkeypatch):
    assert local_jobs.INTERVAL_SECONDS == 60
    monkeypatch.setattr(jobs, 'database', lambda: db)
    calls = []
    def broken():
        calls.append('queue')
        raise OSError('offline')
    monkeypatch.setattr(cleanup, 'run', broken)
    monkeypatch.setattr(cleanup, 'delete_finished_found_photos', lambda: calls.append('found'))
    monkeypatch.setattr(cleanup, 'end_abandoned_found_attempts', lambda: calls.append('abandoned'))
    monkeypatch.setattr(jobs, 'retry_alerts', lambda: calls.append('alerts'))
    monkeypatch.setattr(jobs, 'retry_guardian_alerts', lambda: calls.append('guardian'))
    local_jobs.run_once()
    assert calls == ['queue', 'found', 'abandoned', 'alerts', 'guardian']


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


def test_abandoned_attempt_is_ended_and_its_photo_deleted(db, monkeypatch, photos):
    from datetime import timedelta
    from app import service
    monkeypatch.setattr(cleanup, 'database', lambda: db)
    monkeypatch.setattr(cleanup, 'bucket', service.bucket)
    _, identifier = case()
    old = submit(request_id='abandoned-report-request')
    fresh = submit(request_id='fresh-report-request')
    old_ref = db.collection('found_reports').document(old['id'])
    created = old_ref.get().to_dict()['created_at']
    old_path = old_ref.get().to_dict()['photo_path']
    case_before = dict(db.data['cases/' + identifier])
    cleanup.end_abandoned_found_attempts(now=created + cleanup.ABANDONED_ATTEMPT_AGE - timedelta(seconds=1))
    assert vol().found_photo(old['id'])
    later = created + cleanup.ABANDONED_ATTEMPT_AGE + timedelta(seconds=1)
    fresh_ref = db.collection('found_reports').document(fresh['id'])
    fresh_ref.update({'created_at': later})
    cleanup.end_abandoned_found_attempts(now=later)
    data = old_ref.get().to_dict()
    assert data['ended'] is True and 'photo_path' not in data
    assert not service.bucket().blob(old_path).exists()
    assert old['id'] not in [r['id'] for r in vol().found_list()]
    assert vol().found_photo(fresh['id'])
    assert db.data['cases/' + identifier] == case_before


def test_abandoned_attempt_job_never_touches_confirmed_or_manual_reports(db, monkeypatch, photos):
    from datetime import timedelta
    from app import service
    monkeypatch.setattr(cleanup, 'database', lambda: db)
    monkeypatch.setattr(cleanup, 'bucket', service.bucket)
    case()
    report = submit(request_id='confirmed-report-request')
    ref = db.collection('found_reports').document(report['id'])
    created = ref.get().to_dict()['created_at']
    ref.update({'matched_profile_id': 'someone', 'status': 'identity_confirmed'})
    before = dict(ref.get().to_dict())
    cleanup.end_abandoned_found_attempts(now=created + timedelta(days=30))
    assert ref.get().to_dict() == before


def test_retry_dispatches_existing_cases_without_creating_new_records(db, monkeypatch):
    _, identifier = case()
    monkeypatch.setattr(jobs, 'database', lambda: db)
    dispatch = Mock()
    monkeypatch.setattr(jobs, 'dispatch', dispatch)
    jobs.retry_alerts()
    dispatch.assert_called_once_with(db, identifier, matched=False)
