"""Guardian-side FCM: registration storage/lifecycle (app.service.register_fcm_token)
and best-effort push delivery (app.push.notify_guardian). These tests mock
firebase_admin.messaging.send_each -- they prove the registration lifecycle
and failure-isolation logic is correct, NOT that a real device receives a
real push. Real delivery can only be verified against a real device/project.

Every monkeypatch of firebase_admin.messaging.send_each below goes through
pytest's `monkeypatch` fixture (never a manual attribute assignment), because
`push.messaging` IS the real, process-wide firebase_admin.messaging module --
a manual `del` after a bare assignment does not restore the original function,
it deletes it from the module for the rest of the test process. monkeypatch
guarantees the original is restored after each test regardless of outcome.
"""
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
import pytest
from firebase_admin import messaging
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import service, push
from app.cases import CaseService
from app.case_models import CaseCreate
from firestore_fake import Database, Bucket
from test_cases import guardian_with_individual

@pytest.fixture
def storage(monkeypatch):
    db, bucket = Database(), Bucket()
    db.set(db.collection("events").document("test-event"), {"active": True})
    monkeypatch.setattr(service, "database", lambda: db)
    monkeypatch.setattr(service, "bucket", lambda: bucket)
    monkeypatch.setattr(service.firestore, "transactional", lambda f: f)
    monkeypatch.setattr(push, "database", lambda: db)
    return db, bucket

def registrations_path(uid):
    return f"users/{uid}/fcm_registrations"

def registration_docs(db, uid):
    return {k: v for k, v in db.data.items() if k.startswith(registrations_path(uid) + "/")}

def success(message_id="projects/x/messages/1"):
    return messaging.SendResponse({"name": message_id}, None)

def failure(exception):
    return messaging.SendResponse(None, exception)

class FakeSendEach:
    """Records every call and returns pre-programmed per-message results,
    matched to input messages by token (order-independent, closer to how a
    real batch response should be interpreted than relying on list order)."""
    def __init__(self, outcomes):
        self.outcomes = outcomes  # {token: SendResponse}
        self.calls = []
    def __call__(self, messages):
        self.calls.append(list(messages))
        return messaging.BatchResponse([self.outcomes[m.token] for m in messages])

# --- Registration storage/lifecycle -------------------------------------

def test_a_guardian_can_register_only_their_own_registration(storage):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    docs = registration_docs(db, "owner")
    assert len(docs) == 1
    (path, data), = docs.items()
    assert path.startswith("users/owner/fcm_registrations/")
    assert data["token"] == "token-a"
    # No endpoint/method accepts a guardian id from the caller at all --
    # register_fcm_token has no such parameter; it is always self.uid.
    import inspect
    assert "guardian" not in inspect.signature(service.GuardianService.register_fcm_token).parameters
    assert "uid" not in inspect.signature(service.GuardianService.register_fcm_token).parameters

def test_registration_is_idempotent(storage):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    docs = registration_docs(db, "owner")
    assert len(docs) == 1
    path = next(iter(docs))
    db.data[path]["created_at"] = datetime.now(timezone.utc) - timedelta(days=1)
    original_created_at = db.data[path]["created_at"]
    s.register_fcm_token("token-a")  # Re-upload of the SAME token.
    docs_after = registration_docs(db, "owner")
    assert len(docs_after) == 1  # Still exactly one document, not a duplicate.
    assert docs_after[path]["created_at"] == original_created_at  # Unchanged.
    assert docs_after[path]["updated_at"] > original_created_at  # Refreshed.

def test_multiple_installations_are_registered_independently(storage):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    s.register_fcm_token("token-b")
    docs = registration_docs(db, "owner")
    assert len(docs) == 2
    tokens = {d["token"] for d in docs.values()}
    assert tokens == {"token-a", "token-b"}

def test_registration_refresh_leaves_a_consistent_single_record(storage):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    s.register_fcm_token("token-a")
    s.register_fcm_token("token-a")
    docs = registration_docs(db, "owner")
    assert len(docs) == 1
    assert next(iter(docs.values()))["token"] == "token-a"

def test_a_guardians_registrations_are_not_visible_to_another_guardian(storage):
    db, _ = storage
    s1, _ = guardian_with_individual("owner")
    s2, _ = guardian_with_individual("other")
    s1.register_fcm_token("token-a")
    s2.register_fcm_token("token-b")
    owner_docs, other_docs = registration_docs(db, "owner"), registration_docs(db, "other")
    assert len(owner_docs) == 1 and len(other_docs) == 1
    assert next(iter(owner_docs.values()))["token"] == "token-a"
    assert next(iter(other_docs.values()))["token"] == "token-b"
    assert set(owner_docs) & set(other_docs) == set()  # No path overlap.

# --- Logout / account-switch: a token must never be live under two Guardians

def test_unregister_removes_only_the_callers_own_registration(storage):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    assert len(registration_docs(db, "owner")) == 1
    s.unregister_fcm_token("token-a")
    assert registration_docs(db, "owner") == {}

def test_unregister_is_idempotent(storage):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    s.unregister_fcm_token("token-a")
    s.unregister_fcm_token("token-a")  # Already gone -- must not raise.
    s.unregister_fcm_token("never-registered")  # Never existed -- must not raise.
    assert registration_docs(db, "owner") == {}

def test_unregister_cannot_target_another_guardians_registration(storage):
    # There is no guardian-id parameter anywhere on this path -- the doc it
    # acts on is always derived from the CALLER's own uid, so Guardian B
    # calling unregister with Guardian A's exact token string only ever
    # touches B's own (nonexistent) registration, never A's real one.
    db, _ = storage
    a, _ = guardian_with_individual("guardian-a")
    b, _ = guardian_with_individual("guardian-b")
    a.register_fcm_token("token-a")
    b.unregister_fcm_token("token-a")
    assert len(registration_docs(db, "guardian-a")) == 1  # A's is untouched.
    assert registration_docs(db, "guardian-b") == {}

def test_reregistering_the_same_token_under_a_new_guardian_sweeps_the_old_one(storage):
    # Simulates the exact residual-risk scenario: Guardian A's logout-time
    # unregister never reached the server (e.g. offline), and Guardian B
    # later signs in on the SAME installation. B's own registration must not
    # leave A's stale registration for this identical token still live.
    db, _ = storage
    a, _ = guardian_with_individual("guardian-a")
    b, _ = guardian_with_individual("guardian-b")
    a.register_fcm_token("shared-device-token")
    assert len(registration_docs(db, "guardian-a")) == 1
    b.register_fcm_token("shared-device-token")
    assert registration_docs(db, "guardian-a") == {}  # Swept away.
    b_docs = registration_docs(db, "guardian-b")
    assert len(b_docs) == 1
    assert next(iter(b_docs.values()))["token"] == "shared-device-token"

def test_the_sweep_never_touches_a_guardians_own_second_device(storage):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("phone-token")
    s.register_fcm_token("tablet-token")  # A second, legitimate device.
    assert len(registration_docs(db, "owner")) == 2

def test_the_sweep_never_touches_a_different_guardians_different_token(storage):
    db, _ = storage
    a, _ = guardian_with_individual("guardian-a")
    b, _ = guardian_with_individual("guardian-b")
    a.register_fcm_token("token-a")
    b.register_fcm_token("token-b")  # An unrelated token -- nothing to sweep.
    assert len(registration_docs(db, "guardian-a")) == 1
    assert len(registration_docs(db, "guardian-b")) == 1

def test_after_logout_and_a_new_login_only_the_new_guardian_receives_pushes(storage, monkeypatch):
    # End-to-end simulation of the required outcome: A logs in, logs out
    # (unregister), B logs in on the same installation (same token) -- a
    # subsequent event on one of A's OWN cases must not reach this device,
    # and one of B's must.
    db, _ = storage
    a, a_individual = guardian_with_individual("guardian-a")
    b, b_individual = guardian_with_individual("guardian-b")
    a.register_fcm_token("shared-device-token")
    a.unregister_fcm_token("shared-device-token")  # A logs out.
    b.register_fcm_token("shared-device-token")  # B logs in on the same device.
    sender = FakeSendEach({"shared-device-token": success()})
    monkeypatch.setattr(push.messaging, "send_each", sender)
    push.notify_guardian("guardian-a", kind="case_created", status="report_received", case_id="RD-A", event_id="test-event")
    assert sender.calls == []  # A's push never reached this (or any) device.
    push.notify_guardian("guardian-b", kind="case_created", status="report_received", case_id="RD-B", event_id="test-event")
    assert len(sender.calls) == 1 and sender.calls[0][0].token == "shared-device-token"

# --- Push delivery: failure isolation, never affecting registrations wrongly

def test_a_definitively_unregistered_token_is_removed(storage, monkeypatch):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    monkeypatch.setattr(push.messaging, "send_each",
        FakeSendEach({"token-a": failure(messaging.UnregisteredError("gone"))}))
    push.notify_guardian("owner", kind="case_created", status="report_received", case_id="RD-1", event_id="test-event")
    assert registration_docs(db, "owner") == {}

def test_a_transient_send_failure_does_not_remove_the_registration(storage, monkeypatch):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    for exc in (messaging.QuotaExceededError("busy"), ConnectionError("network down")):
        monkeypatch.setattr(push.messaging, "send_each", FakeSendEach({"token-a": failure(exc)}))
        push.notify_guardian("owner", kind="case_created", status="report_received", case_id="RD-1", event_id="test-event")
        assert len(registration_docs(db, "owner")) == 1, f"survived a transient {type(exc).__name__}"

def test_an_invalid_argument_error_is_not_treated_as_an_invalid_registration(storage, monkeypatch):
    # Explicit case the design decisions called out: a generic invalid-argument
    # response must NOT be interpreted as proof the registration is bad unless
    # Firebase's own semantics specifically say so (UnregisteredError, not
    # InvalidArgumentError/ThirdPartyAuthError/anything else).
    from firebase_admin import exceptions
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    monkeypatch.setattr(push.messaging, "send_each",
        FakeSendEach({"token-a": failure(exceptions.InvalidArgumentError("bad payload"))}))
    push.notify_guardian("owner", kind="case_created", status="report_received", case_id="RD-1", event_id="test-event")
    assert len(registration_docs(db, "owner")) == 1

def test_one_failed_registration_does_not_prevent_delivery_to_the_others(storage, monkeypatch):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-bad")
    s.register_fcm_token("token-good")
    sender = FakeSendEach({
        "token-bad": failure(messaging.UnregisteredError("gone")),
        "token-good": success(),
    })
    monkeypatch.setattr(push.messaging, "send_each", sender)
    push.notify_guardian("owner", kind="case_created", status="report_received", case_id="RD-1", event_id="test-event")
    assert len(sender.calls[0]) == 2  # Both were attempted in the same batch.
    remaining = registration_docs(db, "owner")
    assert len(remaining) == 1
    assert next(iter(remaining.values()))["token"] == "token-good"

def test_send_each_raising_entirely_never_propagates(storage, monkeypatch):
    db, _ = storage
    s, _ = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    def raising(messages):
        raise ConnectionError("FCM unreachable")
    monkeypatch.setattr(push.messaging, "send_each", raising)
    push.notify_guardian("owner", kind="case_created", status="report_received", case_id="RD-1", event_id="test-event")  # Must not raise.
    assert len(registration_docs(db, "owner")) == 1  # Untouched.

def test_no_registrations_is_a_silent_no_op(storage):
    guardian_with_individual("owner")
    push.notify_guardian("owner", kind="case_created", status="report_received", case_id="RD-1", event_id="test-event")

# --- Integration with the business operations it rides along with -------

def test_push_failure_never_fails_case_creation_and_the_notification_still_writes(storage, monkeypatch):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    def raising(messages):
        raise ConnectionError("FCM unreachable")
    monkeypatch.setattr(push.messaging, "send_each", raising)
    created = CaseService(s).create(CaseCreate(individual_id=individual_id))
    assert created["id"].startswith("RD-")
    notifications = CaseService(s).list_notifications()
    assert len(notifications) == 1
    assert notifications[0]["kind"] == "case_created"

def test_push_failure_never_fails_cancel_or_resolve(storage, monkeypatch):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    case_id = CaseService(s).create(CaseCreate(individual_id=individual_id))["id"]
    def raising(messages):
        raise ConnectionError("FCM unreachable")
    monkeypatch.setattr(push.messaging, "send_each", raising)
    resolved = CaseService(s).resolve(case_id)
    assert resolved["status"] == "resolved"

def test_push_payload_contains_only_minimal_navigation_fields(storage, monkeypatch):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    s.register_fcm_token("token-a")
    sender = FakeSendEach({"token-a": success()})
    monkeypatch.setattr(push.messaging, "send_each", sender)
    created = CaseService(s).create(CaseCreate(individual_id=individual_id))
    assert len(sender.calls) == 1
    (message,) = sender.calls[0]
    assert set(message.data.keys()) == {"kind", "status", "case_id", "event_id"}
    assert message.data["case_id"] == created["id"]
    assert message.data["status"] == "report_received"
    # No name, age, photo, guided-report, location, contact info, or token.
    forbidden = ("full_name", "individual_name", "age", "photo", "photo_path",
        "guided_report", "latitude", "longitude", "phone", "email", "token")
    for key in forbidden:
        assert key not in message.data
    # Standard Firebase Messaging notification + data structure -- a visible
    # notification block is present (this is the whole point of the fix),
    # generic/fixed, and carries no case- or individual-specific content.
    assert message.notification is not None
    assert message.notification.title and message.notification.body
    forbidden_text = ("Test Person", "Missing Person", str(individual_id), created["id"])
    for value in forbidden_text:
        assert value not in message.notification.title
        assert value not in message.notification.body

def test_notification_language_follows_the_registrations_own_stored_locale(storage, monkeypatch):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    s.register_fcm_token("token-en", "en")
    s.register_fcm_token("token-ar", "ar")
    sender = FakeSendEach({"token-en": success(), "token-ar": success()})
    monkeypatch.setattr(push.messaging, "send_each", sender)
    CaseService(s).create(CaseCreate(individual_id=individual_id))
    sent = {m.token: m for m in sender.calls[0]}
    assert sent["token-en"].notification.title == "Radd"
    assert sent["token-ar"].notification.title == "راد"
    assert sent["token-en"].notification.body != sent["token-ar"].notification.body
    # Both still carry the identical, minimal data payload regardless of language.
    assert sent["token-en"].data == sent["token-ar"].data

def test_an_unknown_or_missing_locale_falls_back_to_english(storage, monkeypatch):
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    s.register_fcm_token("token-a")  # Default locale, per the model.
    path = next(iter(registration_docs(db, "owner")))
    db.data[path].pop("locale", None)  # Simulate a pre-existing registration without one.
    sender = FakeSendEach({"token-a": success()})
    monkeypatch.setattr(push.messaging, "send_each", sender)
    CaseService(s).create(CaseCreate(individual_id=individual_id))
    assert sender.calls[0][0].notification.title == "Radd"

def test_notification_created_response_is_unaffected_by_registered_push_tokens(storage):
    # Sanity: the existing Firestore notification/case behavior is identical
    # whether or not a Guardian has any FCM registration at all.
    db, _ = storage
    s, individual_id = guardian_with_individual("owner")
    created = CaseService(s).create(CaseCreate(individual_id=individual_id))
    assert created["id"].startswith("RD-")
    assert CaseService(s).list_notifications()[0]["kind"] == "case_created"
