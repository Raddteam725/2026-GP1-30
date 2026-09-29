import base64
import io
import sys
from pathlib import Path
import pytest
from PIL import Image
from fastapi import HTTPException
from pydantic import ValidationError
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import service, push
from app.cases import CaseService, validate_transition
from app.case_models import CaseCreate, GuidedReport, STAGES, TERMINAL_STATUSES
from app.models import ProfileCreate, IndividualInput
from firestore_fake import Database, Bucket, configured_event

@pytest.fixture
def storage(monkeypatch):
    db, bucket = Database(), Bucket()
    db.set(db.collection("events").document("test-event"), configured_event())
    monkeypatch.setattr(service, "database", lambda: db)
    monkeypatch.setattr(service, "bucket", lambda: bucket)
    monkeypatch.setattr(service.firestore, "transactional", lambda f: f)
    # cases.create()/_terminate() fire a best-effort push via app.push, which
    # does its own `from .firebase import database` -- a separate binding
    # from service.database, so it needs its own patch or it would otherwise
    # try to reach real Firebase (harmless since notify_guardian swallows the
    # failure, but real network calls have no place in an isolated unit test).
    monkeypatch.setattr(push, "database", lambda: db)
    return db, bucket

def photo():
    output = io.BytesIO()
    Image.new("RGB", (3, 3), "white").save(output, format="PNG")
    return base64.b64encode(output.getvalue()).decode()

def guardian_with_individual(uid):
    s = service.GuardianService({"uid": uid, "email": uid + "@example.test", "exp": 9999999999, "auth_time": 1})
    s.save_profile(ProfileCreate(full_name="Test Guardian", phone="+966500000001", age_confirmed=True, privacy_accepted=True), create=True)
    individual = s.save(IndividualInput(full_name="Missing Person", age=7, gender="female", relationship="child", photo_base64=photo()))
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

def test_account_verification_issues_a_guardian_scoped_token(storage):
    # Guardian verification is account-level, not per-case (the Volunteer's own
    # current case supplies case context) -- issuance never depends on any
    # particular case existing or being at any particular status.
    s, individual_id = guardian_with_individual("owner")
    result = s.account_verification()
    assert result["payload"].startswith(f"radd:guardian-verification:v1:{s.uid}:")
    assert "expires_at" in result
    # Refreshing rotates the token; the previous nonce alone no longer matches.
    first_nonce = result["payload"].rsplit(":", 1)[-1]
    second = s.account_verification()
    assert second["payload"].rsplit(":", 1)[-1] != first_nonce

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
    assert GuidedReport(same_location=True)  # Permission denied/unavailable: general alert only.
    with pytest.raises(ValidationError):
        GuidedReport(same_location=True, latitude=1)
    with pytest.raises(ValidationError):
        GuidedReport(same_location=False, latitude=1, longitude=1)
    assert GuidedReport(same_location=True, latitude=1, longitude=1)

def test_guided_report_completion_requires_the_core_answers():
    with pytest.raises(ValidationError):
        GuidedReport(completed=True, same_location=False, last_seen_description="x", clothing="shirt", carrying_distinctive=None)
    with pytest.raises(ValidationError):
        GuidedReport(completed=True, same_location=True, latitude=1, longitude=1, clothing="shirt", carrying_distinctive=True)
    assert GuidedReport(completed=True, same_location=True, latitude=1, longitude=1, clothing="shirt", carrying_distinctive=False)

def test_case_retains_age_group_and_closure_timestamp_for_admin_reporting(storage):
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    created = cs.create(CaseCreate(individual_id=individual_id))
    assert created["age_group"] == "6-17"  # guardian_with_individual registers age 7
    assert created["closed_at"] is None
    resolved = cs.resolve(created["id"])
    assert resolved["closed_at"] is not None
    assert resolved["age_group"] == "6-17"  # preserved unchanged through closure

def test_create_case_writes_the_shared_general_alert_intent(storage):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    alerts = [d.to_dict() for d in db.collection("alerts").stream()]
    assert len(alerts) == 1
    assert alerts[0]["case_id"] == case_id
    assert alerts[0]["kind"] == "general"
    assert alerts[0]["delivered"] is False
    assert alerts[0]["recipient_volunteer_id"] is None

def test_active_case_blocks_editing_the_individual_and_lifts_on_cancel(storage):
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    cs.create(CaseCreate(individual_id=individual_id))
    edit = IndividualInput(full_name="Renamed", age=8, gender="female", relationship="child")
    with pytest.raises(HTTPException) as error:
        s.save(edit, individual_id)
    assert error.value.status_code == 409
    case_id = s.get(individual_id).to_dict()["active_case_id"]
    cs.cancel(case_id)
    assert s.get(individual_id).to_dict()["active_case_id"] is None
    assert s.save(edit, individual_id)["full_name"] == "Renamed"

def test_cancel_and_resolve_are_distinct_terminal_outcomes_blocked_once_closed(storage):
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    resolved = cs.resolve(case_id)
    assert resolved["status"] == "resolved"
    with pytest.raises(HTTPException) as error:
        cs.cancel(case_id)
    assert error.value.status_code == 409

    s2, individual_id2 = guardian_with_individual("owner-2")
    cs2 = CaseService(s2)
    case_id2 = cs2.create(CaseCreate(individual_id=individual_id2))["id"]
    cancelled = cs2.cancel(case_id2)
    assert cancelled["status"] == "cancelled"
    assert "cancelled" in TERMINAL_STATUSES and "resolved" in TERMINAL_STATUSES

def test_save_report_is_read_only_once_submitted(storage):
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    complete = GuidedReport(same_location=True, latitude=1, longitude=1, clothing="shirt", carrying_distinctive=False, completed=True)
    cs.save_report(case_id, complete)
    with pytest.raises(HTTPException) as error:
        cs.save_report(case_id, GuidedReport(clothing="different"))
    assert error.value.status_code == 409

def test_guided_report_distinctive_description_is_consistent_with_the_flag():
    with pytest.raises(ValidationError):
        GuidedReport(carrying_distinctive=False, distinctive_description="a red bag")
    with pytest.raises(ValidationError):
        GuidedReport(completed=True, same_location=True, latitude=1, longitude=1, clothing="shirt", carrying_distinctive=True)
    assert GuidedReport(carrying_distinctive=True, distinctive_description="a red bag")


# --- Latest Sprint-0 rules: the Guided Assistant's documented questions only,
# and Saudi phone numbers for Guardian registration ---------------------------

def test_guided_report_completes_without_a_textual_last_seen_answer(storage):
    # "No" to the location question records no location and is not a blocker:
    # the only required answers are location Yes/No, clothing and the
    # distinctive-item Yes/No (plus its description when Yes).
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    report = GuidedReport(same_location=False, clothing="Blue shirt", carrying_distinctive=False, completed=True)
    saved = cs.save_report(case_id, report)["guided_report"]
    assert saved["completed"] is True and saved["latitude"] is None and saved["last_seen_description"] == ""
    with pytest.raises(ValidationError):  # Clothing is still required to complete.
        GuidedReport(same_location=False, carrying_distinctive=False, completed=True)
    with pytest.raises(ValidationError):  # Coordinates only ever accompany a "Yes".
        GuidedReport(same_location=False, latitude=24.7, longitude=46.7, clothing="x", carrying_distinctive=False)

@pytest.mark.parametrize("phone,canonical", [
    ("+966512345678", "+966512345678"), ("0512345678", "+966512345678"),  # mobile, either form
    ("00966 51 234 5678", "+966512345678"), ("966-51-234-5678", "+966512345678"),
    ("٠٥١٢٣٤٥٦٧٨", "+966512345678"),  # Arabic-Indic digits
    ("+966112345678", "+966112345678"), ("0112345678", "+966112345678"),  # Riyadh landline
    ("+201234567890", None), ("+9665123456789", None), ("05123", None), ("+96601234567", None), ("", None)])
def test_guardian_registration_accepts_any_saudi_number_and_stores_it_canonically(phone, canonical):
    from app.models import ProfileUpdate, normalize_saudi_phone
    assert normalize_saudi_phone(phone) == canonical
    if canonical:
        assert ProfileUpdate(full_name="G", phone=phone).phone == canonical
    else:
        with pytest.raises(ValidationError):
            ProfileUpdate(full_name="G", phone=phone)

def test_terminal_vocabulary_is_the_documented_one():
    assert TERMINAL_STATUSES == ("reunited", "resolved", "cancelled", "referred_to_authority")
    assert "transferred_to_authority" not in TERMINAL_STATUSES

def test_deactivated_guardian_is_refused_everywhere_and_receives_no_push(storage, monkeypatch):
    # Admin account management sets users/{uid}.active = false (the Admin
    # module writes it); the Guardian side must refuse every authenticated
    # function and stop push delivery while the durable history remains.
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    s.register_fcm_token("owner-device")
    sent = []
    monkeypatch.setattr(push.messaging, "send_each", lambda messages, app=None: sent.extend(messages))
    monkeypatch.setattr(push, "firebase_app", lambda: None)
    db.data["users/owner"]["active"] = False
    # Every request builds a fresh service (main.service/cases_service), so
    # the account check runs on each of them.
    for action in (s.profile, s.list, lambda: CaseService(s), s.account_verification):
        with pytest.raises(HTTPException) as error:
            action()
        assert error.value.status_code == 403 and error.value.detail == "account_inactive"
    push.notify_guardian("owner", kind="status_update", status="search_in_progress", case_id=case_id, event_id="test-event")
    assert sent == []
    assert db.data[f"users/owner/notifications/{case_id}-search_in_progress"]["status"] == "search_in_progress"
    db.data["users/owner"]["active"] = True  # Reactivation: absent or True means enabled.
    assert s.profile()["full_name"] == "Test Guardian"

def test_referred_to_authority_is_terminal_for_the_guardian(storage):
    # The Admin module performs the transition; the Guardian side treats the
    # result exactly like any other closure: no cancel/resolve, no guided edits.
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    cs = CaseService(s)
    case_id = cs.create(CaseCreate(individual_id=individual_id))["id"]
    db.data[f"cases/{case_id}"].update(status="referred_to_authority", closed_at=db.data[f"cases/{case_id}"]["created_at"])
    assert cs.list()[0]["status"] == "referred_to_authority"
    for action in (lambda: cs.cancel(case_id), lambda: cs.resolve(case_id),
                   lambda: cs.save_report(case_id, GuidedReport(same_location=False))):
        with pytest.raises(HTTPException) as error:
            action()
        assert error.value.status_code == 409 and error.value.detail == "case_closed"
