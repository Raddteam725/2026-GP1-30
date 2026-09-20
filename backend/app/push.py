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
`data` remains data-only, minimal -- kind/status/case_id/event_id, nothing
else. No photo, no exact age, no free text, no location, no contact info, and
never a registration token. The client treats `data` as a hint to refetch
authoritative state from the authenticated backend, never as the state
itself; the foreground handler ignores `notification` entirely (see
GuardianPushService.initialize on the Flutter side) so no duplicate banner
is ever built while the app is open.

Language: chosen per-registration from that installation's own stored
`locale` (Radd's in-app language selection, set at registration time -- see
service.register_fcm_token) picking one of exactly two fixed, already-
translated strings. Never derived from case/individual data, and never a
reason to add a new sensitive field anywhere.

Registration lifecycle: a token is removed ONLY on messaging.UnregisteredError
-- Firebase's own definitive "this registration no longer exists" signal.
Every other outcome (network failure, quota, a generic invalid-argument, the
whole send call raising) is treated as transient and leaves the stored
registration untouched, to be retried on the next triggering event.
"""
from firebase_admin import messaging
from .firebase import database, firebase_app

# Fixed, generic, privacy-safe: no individual's name, no case detail, no
# status-specific wording that could hint at sensitive content. Exactly two
# entries because Radd supports exactly Arabic and English -- add nothing
# case/status-specific here without re-reviewing this file's own privacy
# contract above.
_NOTIFICATION_TEXT = {
    "en": {"title": "Radd", "body": "There is an update on one of your reports."},
    "ar": {"title": "راد", "body": "هناك تحديث على أحد بلاغاتك."},
}

def _registrations(db, guardian_uid):
    return db.collection("users").document(guardian_uid).collection("fcm_registrations")

def notify_guardian(guardian_uid, *, kind, status, case_id, event_id):
    """Best-effort, fire-and-forget. Never raises."""
    try:
        db = database()
        docs = [d for d in _registrations(db, guardian_uid).stream() if (d.to_dict() or {}).get("token")]
        if not docs:
            return
        data = {"kind": kind, "status": status, "case_id": case_id, "event_id": event_id}
        pairs = []
        for doc in docs:
            reg = doc.to_dict()
            text = _NOTIFICATION_TEXT.get(reg.get("locale"), _NOTIFICATION_TEXT["en"])
            # `token=` (not the newer `fid=`) deliberately: this installed
            # firebase-admin flags Message.token as deprecated in favor of a
            # Firebase Installation ID, but the standard FlutterFire
            # `FirebaseMessaging.instance.getToken()` API this project's
            # client uses still returns a classic FCM registration token,
            # not an installation ID -- `fid` is not the value to send.
            message = messaging.Message(
                notification=messaging.Notification(title=text["title"], body=text["body"]),
                data=data,
                token=reg["token"],
            )
            pairs.append((doc, message))
        batch = messaging.send_each([message for _, message in pairs], app=firebase_app())
        for (doc, _), result in zip(pairs, batch.responses):
            if result.success:
                continue
            if isinstance(result.exception, messaging.UnregisteredError):
                # Handled independently per-registration: one invalid device
                # here never stops (or is affected by) any other registration
                # in this same batch.
                try:
                    doc.reference.delete()
                except Exception:
                    pass
            # Any other exception (transient network/service failure, quota,
            # a generic invalid-argument not specifically about this being an
            # unregistered token, ...) is left exactly as-is for the next event.
    except Exception:
        pass
