"""Registration retention and separate terminal-case cleanup tests."""
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
import pytest
from fastapi import HTTPException
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import service, push
from app.cases import CaseService
from app.case_models import CaseCreate
from app.cleanup import expire_photos, scrub_terminal_cases
from firestore_fake import Database, Bucket, configured_event
from test_cases import guardian_with_individual, photo

@pytest.fixture
def storage(monkeypatch):
    db, bucket = Database(), Bucket()
    db.set(db.collection("events").document("test-event"), configured_event())
    monkeypatch.setattr(service, "database", lambda: db)
    monkeypatch.setattr(service, "bucket", lambda: bucket)
    monkeypatch.setattr(service.firestore, "transactional", lambda f: f)
    import app.cases as cases_module, app.cleanup as cleanup_module
    monkeypatch.setattr(cases_module.firestore, "transactional", lambda f: f)
    monkeypatch.setattr(cleanup_module, "database", lambda: db)
    monkeypatch.setattr(cleanup_module, "bucket", lambda: bucket)
    monkeypatch.setattr(push, "database", lambda: db)  # See test_cases.py's storage fixture.
    return db, bucket

def individual_path(s, individual_id):
    return f"users/{s.uid}/individuals/{individual_id}"

def backdate_photo(db, s, individual_id, delta):
    db.data[individual_path(s, individual_id)]["photo_captured_at"] = datetime.now(timezone.utc) - delta

def backdate_case(db, case_id, delta):
    db.data[f"cases/{case_id}"]["closed_at"] = datetime.now(timezone.utc) - delta

# --- Terminal-case 24-hour retention ------------------------------------

def test_terminal_case_is_not_scrubbed_before_24_hours(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    cs.resolve(case_id)
    backdate_case(db, case_id, timedelta(hours=24) - timedelta(seconds=1))
    scrub_terminal_cases()
    data = db.data[f"cases/{case_id}"]
    assert data.get("scrubbed_at") is None
    assert data.get("guardian_id") == "owner"  # Still fully intact.

def test_terminal_case_is_scrubbed_at_and_after_24_hours(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    cs.resolve(case_id)
    backdate_case(db, case_id, timedelta(hours=24))
    scrub_terminal_cases()
    data = db.data[f"cases/{case_id}"]
    assert data.get("scrubbed_at") is not None

def test_scrub_removes_every_identifying_field_and_keeps_only_statistical_ones(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    cs.resolve(case_id)
    backdate_case(db, case_id, timedelta(hours=25))
    scrub_terminal_cases()
    data = db.data[f"cases/{case_id}"]
    # Identifying / relinking / free-text fields: gone.
    for field in ("guardian_id", "individual_id", "individual_path", "individual_name",
                  "age", "guided_report", "guardian_verification", "confirmed_by",
                  "found_report_id", "joined_by", "handed_over_at", "stage_timestamps",
                  "updated_at", "source"):
        assert field not in data, f"{field} should have been scrubbed"
    # Minimum statistical fields: retained, unchanged.
    assert data["status"] == "resolved"
    assert data["age_group"] == "6-17"  # guardian_with_individual registers age 7.
    assert data["created_at"] is not None
    assert data["closed_at"] is not None
    assert data["event_id"] == "test-event"
    # Not a Reunited case -> no Volunteer reference is retained at all.
    assert "handed_over_by" not in data

def test_scrub_retains_the_confirming_volunteer_only_for_reunited_cases(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    # Simulate a completed handover (the real path is exercised end-to-end in
    # test_volunteer_workflow.py; this test is only about the scrub itself).
    db.data[f"cases/{case_id}"].update({"status": "reunited", "handed_over_by": "vol-1", "closed_at": datetime.now(timezone.utc)})
    backdate_case(db, case_id, timedelta(hours=25))
    scrub_terminal_cases()
    data = db.data[f"cases/{case_id}"]
    assert data["handed_over_by"] == "vol-1"
    assert "guardian_id" not in data and "individual_name" not in data

def test_scrub_deletes_linked_found_report_alert_and_notification_debris(storage):
    db, bucket = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    cs.resolve(case_id)
    # A found_reports doc + its Storage photo, standing in for the Volunteer side.
    bucket.blob("found/vol-1/FR-1/x.jpg").upload_from_string(b"x", content_type="image/jpeg")
    db.set(db.collection("found_reports").document("FR-1"), {"case_id": case_id, "photo_path": "found/vol-1/FR-1/x.jpg", "volunteer_uid": "vol-1"})
    assert len(db.collection("users").document("owner").collection("notifications").stream()) == 2  # report_received + resolved
    backdate_case(db, case_id, timedelta(hours=25))
    scrub_terminal_cases()
    assert "found_reports/FR-1" not in db.data
    assert "found/vol-1/FR-1/x.jpg" not in bucket.data
    remaining_alerts = [d for d in db.collection("alerts").stream() if d.to_dict().get("case_id") == case_id]
    assert remaining_alerts == []
    remaining_notifications = [d for d in db.collection("users").document("owner").collection("notifications").stream() if d.to_dict().get("case_id") == case_id]
    assert remaining_notifications == []

def test_scrub_preserves_a_found_report_when_its_photo_deletion_fails(storage):
    db, bucket = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    cs.resolve(case_id)
    path = "found/vol-1/FR-1/x.jpg"
    bucket.blob(path).upload_from_string(b"x", content_type="image/jpeg")
    db.set(db.collection("found_reports").document("FR-1"), {"case_id": case_id, "photo_path": path, "volunteer_uid": "vol-1"})
    backdate_case(db, case_id, timedelta(hours=25))
    bucket.fail_next_delete(path)
    scrub_terminal_cases()
    # The case's own statistical record is still scrubbed independently...
    assert db.data[f"cases/{case_id}"].get("scrubbed_at") is not None
    # ...but the found_report -- the only reference to that photo -- survives
    # so the photo itself is never orphaned in Storage.
    assert "found_reports/FR-1" in db.data
    assert path in bucket.data
    scrub_terminal_cases()  # Retry: the delete succeeds this time.
    assert "found_reports/FR-1" not in db.data
    assert path not in bucket.data

def test_scrub_removes_a_volunteer_notification_even_without_joined_by(storage):
    # A Volunteer who only ever viewed their notification list -- and never
    # clicked Start Search, so never entered joined_by -- can still end up
    # with a case-linked notification (VolunteerWorkflow.notifications_list
    # materializes one lazily for anyone who fetches their list while a case
    # is open). Cleanup must reach it by case_id, not by trusting joined_by.
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    cs.resolve(case_id)
    db.set(db.collection("users").document("vol-onlooker"), {"role": "volunteer", "active": True, "full_name": "Onlooker", "volunteer_id": "V-1"})
    note_path = f"users/vol-onlooker/volunteer_notifications/{case_id}-new"
    db.set(db.collection("users").document("vol-onlooker").collection("volunteer_notifications").document(case_id + "-new"),
        {"case_id": case_id, "event_id": "test-event", "kind": "new_case", "status": "report_received"})
    assert note_path in db.data
    backdate_case(db, case_id, timedelta(hours=25))
    scrub_terminal_cases()
    assert note_path not in db.data

def test_scrub_is_idempotent_on_repeated_runs(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    cs.resolve(case_id)
    backdate_case(db, case_id, timedelta(hours=25))
    scrub_terminal_cases()
    first_pass = dict(db.data[f"cases/{case_id}"])
    scrub_terminal_cases()  # Must not raise or change anything further.
    assert db.data[f"cases/{case_id}"] == first_pass

def test_active_cases_are_never_scrubbed(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    scrub_terminal_cases()
    assert db.data[f"cases/{case_id}"].get("scrubbed_at") is None
    assert db.data[f"cases/{case_id}"]["guardian_id"] == "owner"

# --- Deployment-readiness: the query needs this index against real Firestore

def test_the_composite_index_scrub_terminal_cases_needs_is_declared():
    # scrub_terminal_cases() filters `cases` by an equality (status) AND a
    # range (closed_at) on a DIFFERENT field -- real Firestore requires an
    # explicit composite index for that combination (unlike a single-field
    # range filter such as individuals.photo_captured_at, which is indexed
    # automatically). This only checks the declaration exists and matches
    # the query; it cannot prove the index has been deployed -- that's a
    # `firebase deploy --only firestore:indexes` step for the deployment stage.
    import json
    config = json.loads((Path(__file__).resolve().parents[2] / "firestore.indexes.json").read_text())
    cases_indexes = [i for i in config["indexes"] if i["collectionGroup"] == "cases"]
    assert any(
        [f["fieldPath"] for f in index["fields"]] == ["status", "closed_at"]
        for index in cases_indexes
    ), "expected a composite index on cases(status, closed_at)"
