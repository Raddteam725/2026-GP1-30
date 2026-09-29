"""Isolated shared-document/API tests; no production Firebase calls."""
import sys
from pathlib import Path
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor
from threading import RLock, Barrier
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import volunteer, service, push
from app.main import app
from app.firebase import identity
from app.cases import CaseService
from app.case_models import CaseCreate
from firestore_fake import Database, Bucket, configured_event, server_now
from test_cases import guardian_with_individual

class TransactionDatabase(Database):
    def delete(self, ref):
        self.data.pop(ref.path, None)
    """Serializes test transactions and resolves timestamps/dotted updates.

    This verifies use of the transaction boundary under concurrent callers;
    Firestore itself supplies production conflict retries.
    """
    def __init__(self):
        super().__init__()
        self.lock = RLock()
        self.transactions = 0
    def set(self, ref, value, merge=False):
        def resolve(v):
            if v is volunteer.firestore.SERVER_TIMESTAMP:
                return server_now()
            if isinstance(v, dict): return {k: resolve(x) for k, x in v.items()}
            return v
        super().set(ref, resolve(value), merge)
    def update(self, ref, value):
        for key, v in value.items():
            if '.' in key:
                field, nested = key.split('.', 1)
                v = {**self.data[ref.path].get(field, {}), nested: v}
                key = field
            self.set(ref, {key: v}, merge=True)

@pytest.fixture
def db(monkeypatch):
    db, storage = TransactionDatabase(), Bucket()
    db.set(db.collection('events').document('test-event'), configured_event())
    monkeypatch.setattr(volunteer, 'database', lambda: db)
    monkeypatch.setattr(service, 'database', lambda: db)
    monkeypatch.setattr(service, 'bucket', lambda: storage)
    monkeypatch.setattr(volunteer, 'bucket', lambda: storage)
    # confirm()/handover_found() (app.volunteer_workflow) fire a best-effort
    # Guardian push via app.push, a separate `database` binding of its own.
    monkeypatch.setattr(push, 'database', lambda: db)
    def transactional(fn):
        def run(tx):
            with tx.lock:
                tx.transactions += 1
                return fn(tx)
        return run
    monkeypatch.setattr(volunteer.firestore, 'transactional', transactional)
    for uid in ['one', 'two']:
        db.set(db.collection('events').document('test-event').collection('volunteers').document(uid), {})
        db.set(db.collection('users').document(uid), {'role': 'volunteer', 'active': True,
            'terms_version': 'draft-2026-09', 'privacy_version': 'draft-2026-09',
            'terms_accepted_at': datetime.now(timezone.utc), 'privacy_accepted_at': datetime.now(timezone.utc),
            'full_name': 'Volunteer ' + uid, 'volunteer_id': 'VOL-' + uid,
            'email': uid + '@example.test', 'phone': '+966500000001'})
    yield db
    app.dependency_overrides.clear()

def vol(uid='one', **claims):
    return volunteer.VolunteerService({'uid': uid, **claims})

def case():
    guardian, person = guardian_with_individual('guardian')
    result = CaseService(guardian).create(CaseCreate(individual_id=person))
    return guardian, result['id']

@pytest.mark.parametrize('outcome', ['cancelled', 'resolved'])
def test_closed_state_is_minimal_authoritative_and_scoped_to_previous_recipient(db, outcome):
    from datetime import timedelta
    guardian, identifier = case()
    getattr(CaseService(guardian), 'cancel' if outcome == 'cancelled' else 'resolve')(identifier)
    assert vol().case_state(identifier) == {'id': identifier, 'status': outcome}
    with pytest.raises(HTTPException):
        vol().accessible(identifier)  # Status access never unlocks private details.
    for note in list(vol('two').user.collection('volunteer_notifications').stream()):
        note.reference.delete()
    with pytest.raises(HTTPException):
        vol('two').case_state(identifier)
    db.data['cases/' + identifier]['closed_at'] = datetime.now(timezone.utc) - timedelta(hours=24)
    with pytest.raises(HTTPException):
        vol().case_state(identifier)

def test_profile_from_admin_document_and_no_self_registration(db):
    assert vol().profile()['volunteer_id'] == 'VOL-one'
    from app.alerts import PROXIMITY_RADIUS_METERS
    assert vol().profile()['proximity_radius_meters'] == PROXIMITY_RADIUS_METERS
    db.data['users/one']['active'] = False
    with pytest.raises(HTTPException) as inactive:
        vol().profile()
    assert inactive.value.detail == 'volunteer_inactive'
    with pytest.raises(HTTPException): vol('missing').profile()
    with pytest.raises(HTTPException): vol(role='guardian').profile()
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        assert client.put('/v1/volunteer', json={'active': True}).status_code == 405
        assert client.get('/v1/volunteer').status_code == 403

def test_guardian_cannot_use_any_volunteer_endpoint(db):
    _, case_id = case()
    app.dependency_overrides[identity] = lambda: {'uid': 'guardian'}
    with TestClient(app) as client:
        for path in ['', '/cases/available', '/cases/mine', f'/cases/{case_id}/photo']:
            assert client.get('/v1/volunteer' + path).status_code == 403
        assert client.post(f'/v1/volunteer/cases/{case_id}/start-search').status_code == 403

def test_missing_token_rejected(db):
    with TestClient(app) as client:
        assert client.get('/v1/volunteer').status_code == 401

def test_inactive_cannot_read_cases_join_or_access_photo(db):
    _, case_id = case()
    db.data['users/one']['active'] = False
    for action in [lambda: vol().list(), lambda: vol().list(True), lambda: vol().start_search(case_id), lambda: vol().photo(case_id)]:
        with pytest.raises(HTTPException) as error: action()
        assert error.value.status_code == 403

def test_shared_guardian_case_first_second_join_and_isolation(db):
    guardian, case_id = case()
    first, second = vol(), vol('two')
    assert first.list()[0]['id'] == case_id
    assert first.list(True) == []
    assert first.start_search(case_id)['status'] == 'search_in_progress'
    stored = db.data['cases/' + case_id]
    timestamp = stored['stage_timestamps']['search_in_progress']
    assert first.list() == []
    assert second.list()[0]['id'] == case_id
    assert second.list(True) == []
    second.start_search(case_id)
    first.start_search(case_id)  # idempotent retry
    stored = db.data['cases/' + case_id]
    assert stored['joined_by'] == ['one', 'two']
    assert stored['stage_timestamps']['search_in_progress'] == timestamp
    assert stored['updated_at'] == timestamp or stored['updated_at'] <= timestamp
    assert first.list(True)[0]['id'] == second.list(True)[0]['id'] == case_id
    assert CaseService(guardian).list()[0]['status'] == 'search_in_progress'
    response = first.list(True)[0]
    assert not {'guardian_id', 'individual_path', 'joined_by', 'phone', 'photo_path'} & response.keys()
    assert first.photo(case_id).startswith(b'\xff\xd8')

@pytest.mark.parametrize('status', ['match_confirmed', 'awaiting_guardian_verification', 'reunited'])
def test_only_confirmer_retains_case_after_match(db, status):
    _, case_id = case()
    vol().start_search(case_id)
    vol('two').start_search(case_id)
    db.data['cases/' + case_id].update(status=status, confirmed_by='two')
    assert vol().list() == vol('two').list() == vol().list(True) == []
    assert vol('two').list(True)[0]['id'] == case_id
    with pytest.raises(HTTPException): vol().photo(case_id)
    with pytest.raises(HTTPException): vol('two').start_search(case_id)

def test_event_isolation(db):
    _, case_id = case()
    db.data['cases/' + case_id]['event_id'] = 'other-event'
    assert vol().list() == []
    with pytest.raises(HTTPException): vol().start_search(case_id)
    with pytest.raises(HTTPException): vol().photo(case_id)

def test_concurrent_join_uses_transaction_and_preserves_both_participants(db):
    _, case_id = case()
    barrier = Barrier(2)
    before = db.transactions
    def join(uid):
        barrier.wait(timeout=5)
        return vol(uid).start_search(case_id)
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert all(r['status'] == 'search_in_progress' for r in pool.map(join, ['one', 'two']))
    assert db.transactions == before + 2
    assert set(db.data['cases/' + case_id]['joined_by']) == {'one', 'two'}
    assert set(db.data['cases/' + case_id]['stage_timestamps']) == {'report_received', 'search_in_progress'}

def test_client_uid_never_controls_join(db):
    _, case_id = case()
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    with TestClient(app) as client:
        response = client.post(f'/v1/volunteer/cases/{case_id}/start-search', json={'uid': 'two'})
        assert response.status_code == 200
    assert db.data['cases/' + case_id]['joined_by'] == ['one']
