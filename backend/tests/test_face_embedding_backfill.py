"""Manual backfill safety; all Firebase/model access is mocked."""
import copy
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
import pytest
from app import face_matching
from scripts import backfill_face_embeddings as script
from test_crud import storage, guardian
from test_registration_embeddings import value
from test_face_matching import unit, use_engine


def registration():
    owner = guardian('owner')
    item_id = owner.save(value())['id']
    return owner, item_id, owner.get(item_id).reference


@pytest.mark.parametrize('embedding', [unit(1), None])
def test_backfill_is_idempotent_including_explicit_null(storage, monkeypatch, embedding):
    db, bucket = storage
    owner, item_id, ref = registration()
    before = ref.get().to_dict()
    photos = dict(bucket.data)
    engine = use_engine(monkeypatch, embedding)
    original = engine.embed
    def check(content):
        assert content == photos[before['photo_path']]
        assert face_matching.EMBEDDING_FIELD not in ref.get().to_dict()
        return original(content)
    engine.embed = check
    result = script.backfill(db, bucket, 'test-event', dry_run=False)
    assert result['written'] == 1 and result['no_face'] == (embedding is None)
    after = ref.get().to_dict()
    assert after == {**before, face_matching.EMBEDDING_FIELD: embedding}
    assert bucket.data == photos
    again = script.backfill(db, bucket, 'test-event', dry_run=False)
    assert again['eligible'] == 0 and again['written'] == 0 and engine.calls == 1


def test_default_dry_run_does_not_download_infer_or_write(storage, monkeypatch):
    db, bucket = storage
    registration()
    before = copy.deepcopy(db.data)
    def never(*args, **kwargs):
        pytest.fail('Dry-run must not load AI, access photos or write')
    monkeypatch.setattr(face_matching, 'get_engine', never)
    monkeypatch.setattr(bucket, 'blob', never)
    monkeypatch.setattr(db, 'transaction', never)
    result = script.backfill(db, bucket, 'test-event')
    assert result['eligible'] == 1 and result['written'] == 0
    assert db.data == before


def test_backfill_transaction_retries_do_not_repeat_inference(storage, monkeypatch):
    db, bucket = storage
    registration()
    engine = use_engine(monkeypatch, unit(1))
    original = engine.embed
    state = {'in_transaction': False, 'attempts': 0}
    def checked(content):
        assert not state['in_transaction']
        return original(content)
    engine.embed = checked
    class NoWrites:
        def update(self, *args, **kwargs):
            pass
    def retry(fn):
        def run(tx):
            state['in_transaction'] = True
            try:
                state['attempts'] += 1
                fn(NoWrites())
                state['attempts'] += 1
                return fn(tx)
            finally:
                state['in_transaction'] = False
        return run
    monkeypatch.setattr(script.firestore, 'transactional', retry)
    assert script.backfill(db, bucket, 'test-event', dry_run=False)['written'] == 1
    assert engine.calls == 1 and state['attempts'] == 2


@pytest.mark.parametrize('reason', ['embedding', 'null', 'expired', 'legacy', 'deleting',
                                  'other_event',
                                  'ownership', 'no_photo', 'foreign_photo',
                                  'disabled_guardian', 'wrong_role'])
def test_ineligible_registrations_never_run_ai(storage, monkeypatch, reason):
    db, bucket = storage
    owner, item_id, ref = registration()
    changes = {
        'embedding': {face_matching.EMBEDDING_FIELD: unit(1)},
        'null': {face_matching.EMBEDDING_FIELD: None},
        'expired': {'registration_expires_at': datetime.now(timezone.utc) - timedelta(seconds=1)},
        'legacy': {'registration_expires_at': None},
        'deleting': {'deleting': True},
        'other_event': {'event_id': 'other'},
        'ownership': {'guardian_id': 'other'},
        'no_photo': {'photo_path': None},
        'foreign_photo': {'photo_path': 'found/other/image.jpg'},
    }
    if reason == 'disabled_guardian':
        owner.user.update({'active': False})
    elif reason == 'wrong_role':
        owner.user.update({'role': 'volunteer'})
    else:
        ref.update(changes[reason])
    before = copy.deepcopy(db.data)
    engine = use_engine(monkeypatch, unit(1))
    result = script.backfill(db, bucket, 'test-event', dry_run=False)
    assert result['eligible'] == 0 and result['written'] == 0 and engine.calls == 0
    assert db.data == before


@pytest.mark.parametrize('field', ['active_case_id', 'active_found_report_id'])
def test_active_case_or_found_report_can_receive_missing_embedding(storage, monkeypatch, field):
    db, bucket = storage
    owner, item_id, ref = registration()
    ref.update({field: 'active'})
    before = ref.get().to_dict()
    photos = dict(bucket.data)
    engine = use_engine(monkeypatch, unit(1))

    preview = script.backfill(db, bucket, 'test-event')
    assert preview['eligible'] == 1
    assert preview['written'] == 0
    assert engine.calls == 0

    result = script.backfill(db, bucket, 'test-event', dry_run=False)
    assert result['written'] == 1
    assert result['changed'] == 0
    assert ref.get().to_dict() == {
        **before, face_matching.EMBEDDING_FIELD: unit(1)
    }
    assert bucket.data == photos
    assert engine.calls == 1

    again = script.backfill(db, bucket, 'test-event', dry_run=False)
    assert again['written'] == 0
    assert engine.calls == 1


@pytest.mark.parametrize('new_embedding', [unit(0, 1), 'disabled'])
def test_concurrent_photo_replacement_never_receives_old_embedding(storage, monkeypatch, new_embedding):
    db, bucket = storage
    owner, item_id, ref = registration()
    old = ref.get().to_dict()
    engine = use_engine(monkeypatch, unit(1))
    original = engine.embed
    def replace_during_inference(content):
        assert content == bucket.data[old['photo_path']]
        with monkeypatch.context() as replacing:
            if new_embedding == 'disabled':
                replacing.setattr(face_matching, 'get_engine', lambda: None)
            else:
                use_engine(replacing, new_embedding)
            with ThreadPoolExecutor(max_workers=1) as pool:
                pool.submit(owner.save, value(), item_id).result(timeout=5)
        return original(content)
    engine.embed = replace_during_inference
    result = script.backfill(db, bucket, 'test-event', dry_run=False)
    assert result['changed'] == 1 and result['written'] == 0
    current = ref.get().to_dict()
    assert current['photo_path'] != old['photo_path']
    assert old['photo_path'] not in bucket.data
    if new_embedding == 'disabled':
        assert face_matching.EMBEDDING_FIELD not in current
    else:
        assert current[face_matching.EMBEDDING_FIELD] == new_embedding


@pytest.mark.parametrize('change', ['embedding', 'null', 'capture_timestamp', 'expired',
                                  'deleting', 'deleted', 'active_case', 'guardian', 'event'])
def test_backfill_rechecks_concurrent_changes_inside_transaction(storage, monkeypatch, change):
    db, bucket = storage
    owner, item_id, ref = registration()
    engine = use_engine(monkeypatch, unit(1))
    original = engine.embed
    def changed(content):
        if change == 'embedding':
            ref.update({face_matching.EMBEDDING_FIELD: unit(0, 1)})
        elif change == 'null':
            ref.update({face_matching.EMBEDDING_FIELD: None})
        elif change == 'capture_timestamp':
            ref.update({'photo_captured_at': datetime.now(timezone.utc)})
        elif change == 'expired':
            ref.update({'registration_expires_at': datetime.now(timezone.utc) - timedelta(seconds=1)})
        elif change == 'deleting':
            ref.update({'deleting': True})
        elif change == 'deleted':
            ref.delete()
        elif change == 'active_case':
            ref.update({'active_case_id': 'case'})
        elif change == 'guardian':
            owner.user.update({'active': False})
        else:
            db.collection('events').document('test-event').update({'active': False})
            from firestore_fake import configured_event
            db.collection('events').document('replacement-event').set(configured_event())
        return original(content)
    engine.embed = changed
    result = script.backfill(db, bucket, 'test-event', dry_run=False)
    expected_written = 1 if change == 'active_case' else 0
    assert result['written'] == expected_written
    assert result['changed'] == 1 - expected_written
    current = ref.get().to_dict() or {}
    if change in ('embedding', 'null'):
        assert current[face_matching.EMBEDDING_FIELD] == (None if change == 'null' else unit(0, 1))
    elif change == 'active_case':
        assert current['active_case_id'] == 'case'
        assert current[face_matching.EMBEDDING_FIELD] == unit(1)
    else:
        assert face_matching.EMBEDDING_FIELD not in current


@pytest.mark.parametrize('failure', ['disabled', 'unavailable', 'photo_missing'])
def test_failed_backfill_leaves_embedding_missing(storage, monkeypatch, failure):
    db, bucket = storage
    owner, item_id, ref = registration()
    before = copy.deepcopy(db.data)
    if failure == 'disabled':
        monkeypatch.setattr(face_matching, 'get_engine', lambda: None)
    else:
        use_engine(monkeypatch, 'unavailable' if failure == 'unavailable' else unit(1))
    if failure == 'photo_missing':
        bucket.data.clear()
        assert script.backfill(db, bucket, 'test-event', dry_run=False)['photo_errors'] == 1
    else:
        with pytest.raises(face_matching.Unavailable):
            script.backfill(db, bucket, 'test-event', dry_run=False)
    assert db.data == before


def test_limit_and_resume(storage, monkeypatch):
    db, bucket = storage
    owner, _, _ = registration()
    owner.save(value())
    engine = use_engine(monkeypatch, unit(1))
    for _ in range(2):
        assert script.backfill(db, bucket, 'test-event', dry_run=False, limit=1)['written'] == 1
    assert script.backfill(db, bucket, 'test-event', dry_run=False)['written'] == 0
    assert engine.calls == 2


def test_cli_defaults_to_preview_and_reports_only_counts(storage, monkeypatch, capsys):
    db, bucket = storage
    registration()
    monkeypatch.setattr(script, 'firebase_app', lambda: SimpleNamespace(project_id='test-project'))
    monkeypatch.setattr(script, 'database', lambda: db)
    monkeypatch.setattr(script, 'bucket', lambda: bucket)
    assert script.main(['--project', 'test-project', '--event-id', 'test-event']) == 0
    output = capsys.readouterr().out
    assert 'Dry-run' in output and "'eligible': 1" in output
    assert 'owner' not in output and 'face_embedding' not in output


def test_cli_rejects_project_mismatch_before_reading_data(monkeypatch):
    monkeypatch.setattr(script, 'firebase_app', lambda: SimpleNamespace(project_id='configured'))
    monkeypatch.setattr(script, 'database', lambda: pytest.fail('Project mismatch must not read data'))
    with pytest.raises(SystemExit) as error:
        script.main(['--project', 'other', '--event-id', 'test-event'])
    assert error.value.code == 2


def test_cli_rejects_disabled_apply_before_connecting(monkeypatch):
    monkeypatch.setattr(script, 'firebase_app', lambda: pytest.fail('Disabled apply must not connect'))
    with pytest.raises(SystemExit) as error:
        script.main(['--project', 'test-project', '--event-id', 'test-event', '--apply'])
    assert error.value.code == 2


def test_cli_unavailable_errors_do_not_expose_sensitive_payload(storage, monkeypatch, capsys):
    db, bucket = storage
    registration()
    engine = use_engine(monkeypatch, unit(1))
    def fail(content):
        raise face_matching.Unavailable('sensitive photo or vector payload')
    engine.embed = fail
    monkeypatch.setattr(script, 'firebase_app', lambda: SimpleNamespace(project_id='test-project'))
    monkeypatch.setattr(script, 'database', lambda: db)
    monkeypatch.setattr(script, 'bucket', lambda: bucket)
    assert script.main(['--project', 'test-project', '--event-id', 'test-event', '--apply']) == 1
    assert 'sensitive' not in capsys.readouterr().out
