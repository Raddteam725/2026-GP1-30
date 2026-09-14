import base64
import io
import sys
from pathlib import Path
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.main import app
from app.models import ProfileCreate, IndividualInput
from app.service import owned_registration, ensure_deletable, assert_guardian_role, normalize_photo

def test_protected_endpoints_require_token():
    with TestClient(app) as client:
        for path in ("/v1/session", "/v1/guardian", "/v1/individuals", "/v1/individuals/other", "/v1/individuals/other/photo"):
            assert client.get(path).status_code == 401
        assert client.get("/health").json() == {"status": "ok"}

def test_profile_confirmations_and_phone():
    valid = dict(full_name=" Guardian ", phone="+966500000001", age_confirmed=True, privacy_accepted=True)
    assert ProfileCreate(**valid).full_name == "Guardian"
    for changes in ({"age_confirmed": False}, {"privacy_accepted": False}, {"phone": "123"}, {"full_name": " "}):
        with pytest.raises(ValidationError):
            ProfileCreate(**(valid | changes))

def test_individual_validation():
    valid = dict(full_name=" Person ", age=0, gender="female", relationship="daughter")
    assert IndividualInput(**valid).full_name == "Person"
    for changes in ({"age": -1}, {"age": 131}, {"age": 1.5}, {"full_name": " "}, {"gender": ""}, {"guardian_id": "another"}):
        with pytest.raises(ValidationError):
            IndividualInput(**(valid | changes))

def test_ownership_and_role_not_client_controlled():
    for record in (None, {"guardian_id": "other"}):
        with pytest.raises(HTTPException) as error:
            owned_registration(record, "owner")
        assert error.value.status_code == 404
    assert owned_registration({"guardian_id": "owner"}, "owner")
    with pytest.raises(HTTPException):
        assert_guardian_role({"role": "volunteer"}, {"role": "guardian"})
    with pytest.raises(HTTPException):
        assert_guardian_role({}, {"role": "volunteer"})

def test_delete_guard_allows_no_case_but_rejects_active_case():
    ensure_deletable({})
    with pytest.raises(HTTPException) as error:
        ensure_deletable({"active_case_id": "test-case"})
    assert error.value.status_code == 409

def test_photo_validation_and_metadata_removal():
    with pytest.raises(HTTPException):
        normalize_photo("not an image")
    source = io.BytesIO()
    Image.new("RGB", (4, 4), "white").save(source, format="PNG")
    result = normalize_photo(base64.b64encode(source.getvalue()).decode())
    with Image.open(io.BytesIO(result)) as photo:
        assert photo.format == "JPEG"
        assert not photo.getexif()
