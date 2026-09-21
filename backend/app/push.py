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
import logging
import time
from datetime import datetime, timedelta, timezone
from firebase_admin import messaging, firestore, auth
from . import delivery_queue
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
    """Persist first, then enqueue an immediate bounded local delivery attempt."""
    try:
        db = database()
        ref = db.collection('users').document(guardian_uid).collection('notifications').document(case_id + '-' + status)
        @firestore.transactional
        def record(tx):
            if not ref.get(transaction=tx).exists:
                tx.set(ref, {'case_id': case_id, 'event_id': event_id, 'kind': kind,
                    'status': status, 'created_at': firestore.SERVER_TIMESTAMP, 'read_at': None})
        if not ref.get().exists:
            record(db.transaction())
        logging.getLogger('uvicorn.error').info('Radd Guardian event %s T3 history_ready epoch_ms=%d', ref.id, time.time()*1000)
        delivery_queue.submit(ref.path, lambda: _deliver_guardian(guardian_uid, kind=kind,
            status=status, case_id=case_id, event_id=event_id))
    except Exception as error:
        logging.getLogger('uvicorn.error').warning('Guardian event pending retry (%s)', type(error).__name__)

def _deliver_guardian(guardian_uid, *, kind, status, case_id, event_id):
    """Recheck live session eligibility in the worker; never return a fake receipt."""
    try:
        db = database()
        docs = [d for d in _registrations(db, guardian_uid).stream() if (d.to_dict() or {}).get("token")]
        if (db.collection('users').document(guardian_uid).get().to_dict() or {}).get('role') != 'guardian':
            return
        now = datetime.now(timezone.utc)
        docs = [d for d in docs if d.to_dict().get('session_expires_at', 0) > now.timestamp()]
        if not docs:
            return
        account = auth.get_user(guardian_uid, app=firebase_app())
        if account.disabled:
            return
        docs = [d for d in docs if d.to_dict().get('session_auth_time', 0) >= account.tokens_valid_after_timestamp / 1000]
        notification = db.collection('users').document(guardian_uid).collection('notifications').document(case_id + '-' + status)
        if not notification.get().exists:
            return
        data = {"kind": kind, "status": status, "case_id": case_id, "event_id": event_id, "role": "guardian", "notification_id": case_id + "-" + status}
        pairs = []
        for doc in docs:
            receipt = notification.collection('deliveries').document(doc.id)
            @firestore.transactional
            def claim(tx):
                previous = receipt.get(transaction=tx).to_dict() or {}
                if previous.get('sent_at') or previous.get('lease_until', now) > now:
                    return False
                tx.set(receipt, {'lease_until': now + timedelta(seconds=60)})
                return True
            if not claim(db.transaction()):
                continue
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
                android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(tag=notification.id)),
            )
            pairs.append((doc, message))
        if not pairs:
            return
        logging.getLogger('uvicorn.error').info('Radd Guardian event %s T4 fcm_start epoch_ms=%d', notification.id, time.time()*1000)
        try:
            batch = messaging.send_each([message for _, message in pairs], app=firebase_app())
        except Exception:
            for doc, _ in pairs:
                try:
                    notification.collection('deliveries').document(doc.id).delete()
                except Exception as error:
                    logging.getLogger('uvicorn.error').warning('Lease cleanup pending expiry (%s)', type(error).__name__)
            raise
        for (doc, _), result in zip(pairs, batch.responses):
            receipt = notification.collection('deliveries').document(doc.id)
            if result.success:
                receipt.set({'sent_at': firestore.SERVER_TIMESTAMP})
                logging.getLogger('uvicorn.error').info('Radd Guardian event %s T5 fcm_accepted epoch_ms=%d', notification.id, time.time()*1000)
                continue
            receipt.delete()
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
    except Exception as error:
        logging.getLogger('uvicorn.error').warning('Guardian FCM pending retry (%s)', type(error).__name__)


def retry_guardian_alerts():
    """Replay durable unacknowledged status notifications, never recreate history."""
    from google.cloud.firestore_v1.base_query import FieldFilter
    db = database()
    for user in db.collection('users').where(filter=FieldFilter('role', '==', 'guardian')).stream():
        for note in user.reference.collection('notifications').stream():
            data = note.to_dict() or {}
            case = db.collection('cases').document(data.get('case_id', '_missing')).get().to_dict() or {}
            closed = case.get('closed_at')
            if not case or case.get('scrubbed_at') or (closed and datetime.now(timezone.utc)-closed >= timedelta(hours=24)):
                continue
            if data.get('case_id') and data.get('status') and data.get('event_id'):
                delivery_queue.submit(note.reference.path, lambda uid=user.id, d=data: _deliver_guardian(uid,
                    kind=d.get('kind', 'status_update'), status=d['status'], case_id=d['case_id'], event_id=d['event_id']))
