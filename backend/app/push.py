"""Guardian push delivery: an ADDITIONAL channel alongside the existing
Firestore notification record (see cases.py/volunteer_workflow.py) -- never a
replacement for it, and never allowed to affect the business operation it
rides along with. Every call site wraps notify_guardian in its own
try/except too; this module's own top-level catch is the second line of
defense, not the only one.

Message structure: standard Firebase Messaging notification + data message.
The `notification` block is a single, fixed, generic, pre-translated string
pair (see _NOTIFICATION_TEXT) -- it names neither the individual nor any case
detail, so it is safe for Android to display in the system tray while the app
is backgrounded or terminated. It is also standard: nothing here builds or
displays a notification directly (no local-notification package); Android's
own FCM handling does that automatically for a backgrounded/terminated app.
`data` remains data-only, minimal -- role/kind/status/case_id/event_id,
nothing else. No photo, no exact age, no free text, no location, no contact
info, and never a registration token. The client treats `data` as a hint to
refetch authoritative state from the authenticated backend, never as the
state itself; `role` + `case_id` + `status` are what the client validates and
de-duplicates on (see GuardianCaseEvents on the Flutter side).

Language: chosen per-registration from that installation's own stored
`locale` (Radd's in-app language selection, set at registration time -- see
service.register_fcm_token) picking one of exactly two fixed, already-
translated strings. Never derived from case/individual data, and never a
reason to add a new sensitive field anywhere.

Delivery, receipts, retry and the registration-removal rule (only on
messaging.UnregisteredError) are the shared app.delivery contract, identical
for both roles; which registrations are eligible is the shared app.sessions
contract. The durable notification document written by the caller
(`users/{uid}/notifications/{case}-{status}`) is what the delivery receipts
hang off, so the reconciliation job can retry exactly the pushes FCM never
accepted (see retry_recent).
"""
from datetime import datetime, timedelta, timezone
from firebase_admin import messaging
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import database, firebase_app
from .delivery import deliver
from .sessions import eligible_registrations

# Fixed, generic, privacy-safe: no individual's name, no case detail, no
# status-specific wording that could hint at sensitive content. Exactly two
# entries because Radd supports exactly Arabic and English -- add nothing
# case/status-specific here without re-reviewing this file's own privacy
# contract above.
_NOTIFICATION_TEXT = {
    "en": {"title": "Radd", "body": "There is an update on one of your reports."},
    "ar": {"title": "راد", "body": "هناك تحديث على أحد بلاغاتك."},
}

# How far back the reconciliation job looks for Guardian notifications whose
# push FCM never accepted. Anything older is covered by the app's own
# authoritative refetch on open/resume.
RETRY_WINDOW = timedelta(hours=1)

def _registrations(db, guardian_uid):
    return db.collection("users").document(guardian_uid).collection("fcm_registrations")

def notification_id(case_id, status):
    # The one id scheme every Guardian notification writer uses
    # (cases.create/_terminate, volunteer.start_search, volunteer_workflow.*,
    # scripts/dev_case_state.py), so push receipts always find their record.
    return case_id + "-" + status

def notify_guardian(guardian_uid, *, kind, status, case_id, event_id):
    """Best-effort, never raises: immediate push for an already-committed
    notification record. Returns the delivery summary (see app.delivery)."""
    try:
        db = database()
        user = db.collection("users").document(guardian_uid)
        registrations = eligible_registrations(user, guardian_uid)
        if not registrations:
            return None
        data = {"role": "guardian", "kind": kind, "status": status, "case_id": case_id, "event_id": event_id}
        def build(registration):
            text = _NOTIFICATION_TEXT.get(registration.get("locale"), _NOTIFICATION_TEXT["en"])
            # `token=` (not the newer `fid=`) deliberately: this installed
            # firebase-admin flags Message.token as deprecated in favor of a
            # Firebase Installation ID, but the standard FlutterFire
            # `FirebaseMessaging.instance.getToken()` API this project's
            # client uses still returns a classic FCM registration token,
            # not an installation ID -- `fid` is not the value to send.
            return messaging.Message(
                notification=messaging.Notification(title=text["title"], body=text["body"]),
                data=data,
                token=registration["token"],
            )
        return deliver(db, user.collection("notifications").document(notification_id(case_id, status)),
                       registrations, build, app=firebase_app())
    except Exception:
        return None

def retry_recent(db=None):
    """Reconciliation: re-attempt every recent Guardian notification whose
    push was never accepted (receipts make an accepted one a no-op). Part of
    the maintenance run -- never the normal path, which is the immediate
    attempt inside the request that committed the record."""
    db = db or database()
    cutoff = datetime.now(timezone.utc) - RETRY_WINDOW
    for guardian in db.collection("users").where(filter=FieldFilter("role", "==", "guardian")).stream():
        recent = guardian.reference.collection("notifications").where(filter=FieldFilter("created_at", ">=", cutoff)).stream()
        for note in recent:
            data = note.to_dict() or {}
            if not data.get("case_id") or not data.get("status"):
                continue
            notify_guardian(guardian.id, kind=data.get("kind", "status_update"), status=data["status"],
                            case_id=data["case_id"], event_id=data.get("event_id"))
