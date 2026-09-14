import base64
import io
import sys
from pathlib import Path
import pytest
from PIL import Image
from fastapi import HTTPException
from pydantic import ValidationError
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import service
from app.cases import CaseService, validate_transition
from app.case_models import CaseCreate, GuidedReport, STAGES
from app.models import ProfileCreate, IndividualInput
from firestore_fake import Database, Bucket

@pytest.fixture
def storage(monkeypatch):
    db, bucket = Database(), Bucket()
    db.set(db.collection("events").document("test-event"), {"active": True})
    monkeypatch.setattr(service, "database", lambda: db)
    monkeypatch.setattr(service, "bucket", lambda: bucket)
    monkeypatch.setattr(service.firestore, "transactional", lambda f: f)
    return db, bucket

def photo():
    output = io.BytesIO()
    Image.new("RGB", (3, 3), "white").save(output, format="PNG")
    return base64.b64encode(output.getvalue()).decode()

def guardian_with_individual(uid):
    s = service.GuardianService({"uid": uid, "email": uid + "@example.test"})
    s.save_profile(ProfileCreate(full_name="Test Guardian", phone="+966500000001", age_confirmed=True, privacy_accepted=True), create=True)
    individual = s.save(IndividualInput(full_name="Missing Person", age=7, gender="female", relationship="daughter", photo_base64=photo()))
    return s, individual["id"]

def test_create_case_sets_active_case_id_and_notifies(storage):
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    created = cs.create(CaseCreate(individual_id=individual_id))
    assert created["id"].startswith("RD-")
    assert created["status"] == STAGES[0]
    assert created["individual_id"] == individual_id
    assert s.get(individual_id).to_dict()["active_case_id"] == created["id"]
    notifications = cs.list_notifications()
    assert len(notifications) == 1
    assert notifications[0]["kind"] == "case_created"
    assert notifications[0]["read_at"] is None

def test_create_case_is_idempotent_for_the_same_individual(storage):
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    first = cs.create(CaseCreate(individual_id=individual_id))
    second = cs.create(CaseCreate(individual_id=individual_id))
    assert first["id"] == second["id"]
    assert len(cs.list()) == 1

def test_create_case_fails_closed_without_an_active_event(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    db.data.pop("events/test-event")
    cs = CaseService(s)
    with pytest.raises(HTTPException) as error:
        cs.create(CaseCreate(individual_id=individual_id))
    assert error.value.status_code == 503

def test_owned_rejects_cross_guardian_access(storage):
    s, individual_id = guardian_with_individual("owner")
    other, _ = guardian_with_individual("intruder")
    case_id = CaseService(s).create(CaseCreate(individual_id=individual_id))["id"]
    with pytest.raises(HTTPException) as error:
        CaseService(other).owned(case_id)
    assert error.value.status_code == 404

def test_save_report_rejects_a_closed_case(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    db.update(cs.cases.document(case_id), {"status": "reunited"})
    with pytest.raises(HTTPException) as error:
        cs.save_report(case_id, GuidedReport())
    assert error.value.status_code == 409

def test_save_report_persists_guided_answers(storage):
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    report = GuidedReport(same_location=False, last_seen_description="Near the market", clothing="Blue shirt", carrying_distinctive=False, completed=True)
    updated = cs.save_report(case_id, report)
    assert updated["guided_report"]["last_seen_description"] == "Near the market"
    assert updated["guided_report"]["completed"] is True

def test_verification_requires_awaiting_guardian_verification_status(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    with pytest.raises(HTTPException) as error:
        cs.verification(case_id)
    assert error.value.status_code == 409
    db.update(cs.cases.document(case_id), {"status": "awaiting_guardian_verification"})
    result = cs.verification(case_id)
    assert result["case_id"] == case_id
    assert result["payload"].startswith(f"radd:guardian-verification:v1:{case_id}:")

def test_notifications_are_scoped_and_mark_read_is_idempotent(storage):
    s, individual_id = guardian_with_individual("owner")
    other, _ = guardian_with_individual("bystander")
    cs, other_cs = CaseService(s), CaseService(other)
    cs.create(CaseCreate(individual_id=individual_id))
    assert other_cs.list_notifications() == []
    notification_id = cs.list_notifications()[0]["id"]
    cs.mark_read(notification_id)
    cs.mark_read(notification_id)
    assert cs.list_notifications()[0]["read_at"] is not None
    with pytest.raises(HTTPException) as error:
        cs.mark_read("missing-notification")
    assert error.value.status_code == 404

def test_validate_transition_enforces_ordered_progression():
    validate_transition(STAGES[0], STAGES[1])
    with pytest.raises(HTTPException) as error:
        validate_transition(STAGES[0], STAGES[2])
    assert error.value.status_code == 409
    with pytest.raises(HTTPException):
        validate_transition(STAGES[1], STAGES[0])
    with pytest.raises(HTTPException):
        validate_transition("unknown", STAGES[0])

def test_guided_report_requires_coordinates_only_when_same_location():
    with pytest.raises(ValidationError):
        GuidedReport(same_location=True)
    with pytest.raises(ValidationError):
        GuidedReport(same_location=False, latitude=1, longitude=1)
    assert GuidedReport(same_location=True, latitude=1, longitude=1)

def test_guided_report_completion_requires_the_core_answers():
    with pytest.raises(ValidationError):
        GuidedReport(completed=True, same_location=False, last_seen_description="x", clothing="shirt", carrying_distinctive=None)
    with pytest.raises(ValidationError):
        GuidedReport(completed=True, same_location=True, latitude=1, longitude=1, clothing="shirt", carrying_distinctive=True)
    assert GuidedReport(completed=True, same_location=True, latitude=1, longitude=1, clothing="shirt", carrying_distinctive=False)

def test_guided_report_distinctive_description_is_consistent_with_the_flag():
    with pytest.raises(ValidationError):
        GuidedReport(carrying_distinctive=False, distinctive_description="a red bag")
    with pytest.raises(ValidationError):
        GuidedReport(completed=True, same_location=True, latitude=1, longitude=1, clothing="shirt", carrying_distinctive=True)
    assert GuidedReport(carrying_distinctive=True, distinctive_description="a red bag")
