import base64
import io
import sys
from pathlib import Path
import pytest
from PIL import Image
from fastapi import HTTPException
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import service
from app.models import ProfileCreate, IndividualInput

class Snapshot:
    def __init__(self, ref):
        self.reference = ref
        self.id = ref.path.split("/")[-1]
        self.exists = ref.path in ref.db.data
    def to_dict(self):
        value = self.reference.db.data.get(self.reference.path)
        return dict(value) if value is not None else None

class Reference:
    def __init__(self, db, path):
        self.db, self.path = db, path
        self.id = path.split("/")[-1]
    def get(self, transaction=None):
        return Snapshot(self)
    def collection(self, name):
        return Collection(self.db, self.path + "/" + name)
    def delete(self):
        self.db.data.pop(self.path, None)

class Collection:
    def __init__(self, db, path):
        self.db, self.path = db, path
    def document(self, name=None):
        self.db.counter += 1
        return Reference(self.db, self.path + "/" + (name or str(self.db.counter)))
    def stream(self):
        prefix = self.path + "/"
        return [Snapshot(Reference(self.db, p)) for p in list(self.db.data) if p.startswith(prefix) and "/" not in p[len(prefix):]]
    def add(self, value):
        self.db.set(self.document(), value)

class Database:
    def __init__(self):
        self.data, self.counter = {}, 0
    def collection(self, name):
        return Collection(self, name)
    def transaction(self):
        return self
    def set(self, ref, value, merge=False):
        self.data[ref.path] = (self.data.get(ref.path, {}) if merge else {}) | value
    def update(self, ref, value):
        self.set(ref, value, merge=True)

class Blob:
    def __init__(self, store, path):
        self.store, self.path = store, path
    def upload_from_string(self, data, content_type):
        assert content_type == "image/jpeg"
        self.store[self.path] = data
    def download_as_bytes(self):
        return self.store[self.path]
    def exists(self):
        return self.path in self.store
    def delete(self):
        self.store.pop(self.path)

class Bucket:
    def __init__(self):
        self.data = {}
    def blob(self, path):
        return Blob(self.data, path)

@pytest.fixture
def storage(monkeypatch):
    db, bucket = Database(), Bucket()
    monkeypatch.setattr(service, "database", lambda: db)
    monkeypatch.setattr(service, "bucket", lambda: bucket)
    monkeypatch.setattr(service.firestore, "transactional", lambda f: f)
    return db, bucket

def guardian(uid):
    s = service.GuardianService({"uid": uid, "email": uid + "@example.test"})
    s.save_profile(ProfileCreate(full_name="Test Guardian", phone="+966500000001", age_confirmed=True, privacy_accepted=True), create=True)
    return s

def photo():
    output = io.BytesIO()
    Image.new("RGB", (3, 3), "white").save(output, format="PNG")
    return base64.b64encode(output.getvalue()).decode()

def test_real_service_crud_scopes_ownership_and_removes_photo(storage):
    first, second = guardian("one"), guardian("two")
    assert first.list() == []
    value = IndividualInput(full_name="Test Person", age=7, gender="female", relationship="daughter", photo_base64=photo())
    created = first.save(value)
    assert len(first.list()) == 1
    assert second.list() == []
    with pytest.raises(HTTPException) as error:
        second.get(created["id"])
    assert error.value.status_code == 404
    with pytest.raises(HTTPException):
        second.delete(created["id"])
    updated = first.save(value.model_copy(update={"full_name": "Updated Person", "photo_base64": None}), created["id"])
    assert updated["full_name"] == "Updated Person"
    assert first.photo(created["id"]).startswith(b"\xff\xd8")
    first.delete(created["id"])
    assert first.list() == []
    assert storage[1].data == {}

def test_replacement_removes_old_photo(storage):
    s = guardian("owner")
    value = IndividualInput(full_name="Person", age=0, gender="male", relationship="son", photo_base64=photo())
    created = s.save(value)
    old_path = next(iter(storage[1].data))
    s.save(value, created["id"])
    assert len(storage[1].data) == 1
    assert old_path not in storage[1].data

def test_active_case_restriction_is_enforced_transactionally(storage):
    s = guardian("owner")
    value = IndividualInput(full_name="Person", age=7, gender="male", relationship="son", photo_base64=photo())
    created = s.save(value)
    ref = s.get(created["id"]).reference
    storage[0].update(ref, {"active_case_id": "test-active-case"})
    with pytest.raises(HTTPException) as error:
        s.delete(created["id"])
    assert error.value.status_code == 409
    assert len(s.list()) == 1
    assert len(storage[1].data) == 1

def test_existing_non_guardian_cannot_self_assign_guardian(storage):
    db, _ = storage
    db.set(db.collection("users").document("volunteer"), {"role": "volunteer"})
    with pytest.raises(HTTPException):
        guardian("volunteer")

def test_profile_email_comes_from_verified_identity(storage):
    s = guardian("owner")
    storage[0].update(s.user, {"email": "stale@example.test"})
    assert s.profile()["email"] == "owner@example.test"
    assert s.profile()["full_name"] == "Test Guardian"

def test_session_role_is_server_owned_and_missing_profile_is_recoverable(storage):
    db, _ = storage
    s = service.GuardianService({"uid": "partial", "email": "partial@example.test"})
    with pytest.raises(HTTPException) as missing:
        s.account_role()
    assert missing.value.status_code == 404
    db.data["users/partial"] = {"role": "volunteer"}
    assert s.account_role() == {"role": "volunteer"}
    with pytest.raises(HTTPException):
        s.profile()
    db.data["users/partial"] = {"role": "guardian"}
    assert s.account_role() == {"role": "guardian"}
    with pytest.raises(HTTPException) as incomplete:
        s.profile()
    assert incomplete.value.status_code == 404
    result = s.save_profile(ProfileCreate(full_name="Recovered Guardian", phone="+966500000001", age_confirmed=True, privacy_accepted=True), create=True)
    assert result["full_name"] == "Recovered Guardian"
    assert result["email"] == "partial@example.test"
    assert list(db.data) == ["users/partial"]

def test_session_rejects_unknown_or_conflicting_role(storage):
    db, _ = storage
    db.data["users/one"] = {"role": "admin"}
    with pytest.raises(HTTPException):
        service.GuardianService({"uid": "one"}).account_role()
    db.data["users/one"] = {"role": "guardian"}
    with pytest.raises(HTTPException):
        service.GuardianService({"uid": "one", "role": "volunteer"}).account_role()
