"""Shared retention test fixture and preserved index declaration."""
from workflow_fixtures import historical_closure
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
import pytest
from fastapi import HTTPException
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import service, push
from app.cases import CaseService
from app.case_models import CaseCreate
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

# The 24-hour terminal-case scrubber (PBIs 35/37) is Release 2 work and is no
# longer part of cleanup; its composite index declaration is preserved.

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
