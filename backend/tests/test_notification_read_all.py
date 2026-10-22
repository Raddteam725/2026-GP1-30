"""Bulk read endpoints operate only on the authenticated role's own inbox."""
from datetime import datetime, timezone
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.firebase import identity
from test_cases import guardian_with_individual
from test_volunteer import db


@pytest.mark.parametrize('role', ['guardian', 'volunteer'])
@pytest.mark.parametrize('count', [0, 3, 501])
def test_read_all_scopes_owner_role_and_event_and_is_idempotent(db, role, count):
    guardian_with_individual('guardian')
    guardian_with_individual('other-guardian')
    uid = 'guardian' if role == 'guardian' else 'one'
    collection = 'notifications' if role == 'guardian' else 'volunteer_notifications'
    other_collection = 'volunteer_notifications' if role == 'guardian' else 'notifications'
    inbox = db.collection('users').document(uid).collection(collection)
    for i in range(count):
        inbox.document(str(i)).set({'read_at': None, 'event_id': 'test-event', 'status': 'reunited'})
    read_at = datetime(2026, 1, 1, tzinfo=timezone.utc)
    inbox.document('already-read').set({'read_at': read_at, 'event_id': 'test-event'})
    inbox.document('old-event').set({'read_at': None, 'event_id': 'old-event'})
    db.collection('users').document(uid).collection(other_collection).document('other-role').set({'read_at': None})
    other_uid = 'other-guardian' if role == 'guardian' else 'two'
    other = db.collection('users').document(other_uid).collection(collection).document('other-owner')
    other.set({'read_at': None, 'event_id': 'test-event'})
    before = {path: dict(value) for path, value in db.data.items()}
    app.dependency_overrides[identity] = lambda: {'uid': uid}
    client = TestClient(app)
    path = '/v1/notifications/read-all' if role == 'guardian' else '/v1/volunteer/notifications/read-all'
    assert client.put(path).status_code == 204
    eligible = count + int(role == 'guardian')
    assert db.batches == (eligible + 499) // 500
    for i in range(count):
        assert inbox.document(str(i)).get().to_dict()['read_at'] is not None
    assert inbox.document('already-read').get().to_dict()['read_at'] == read_at
    assert other.get().to_dict()['read_at'] is None
    for record_path, value in before.items():
        if not record_path.startswith(inbox.path + '/'):
            assert db.data[record_path] == value
    assert (inbox.document('old-event').get().to_dict()['read_at'] is None) == (role == 'volunteer')
    after = {path: dict(value) for path, value in db.data.items()}
    assert client.put(path).status_code == 204
    assert db.data == after
    assert db.batches == (eligible + 499) // 500


@pytest.mark.parametrize('role', ['guardian', 'volunteer'])
def test_read_all_requires_authentication(role):
    client = TestClient(app)
    path = '/v1/notifications/read-all' if role == 'guardian' else '/v1/volunteer/notifications/read-all'
    assert client.put(path).status_code == 401


def test_volunteer_read_all_includes_lazily_created_listed_alerts(db):
    from app.cases import CaseService
    from app.case_models import CaseCreate
    guardian, person = guardian_with_individual('guardian')
    CaseService(guardian).create(CaseCreate(individual_id=person))
    app.dependency_overrides[identity] = lambda: {'uid': 'one'}
    client = TestClient(app)
    assert client.put('/v1/volunteer/notifications/read-all').status_code == 204
    notes = client.get('/v1/volunteer/notifications').json()
    assert notes and all(n['read_at'] is not None for n in notes)
