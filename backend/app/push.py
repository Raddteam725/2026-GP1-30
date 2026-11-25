import logging
import time
from datetime import datetime, timedelta, timezone
from firebase_admin import messaging, firestore, auth
from . import delivery_queue
from .firebase import database, firebase_app

_NOTIFICATION_TEXT = {
    "en": {"title": "Radd", "body": "There is an update on one of your reports."},
    "ar": {"title": "راد", "body": "هناك تحديث على أحد بلاغاتك."},
}

def _registrations(db, guardian_uid):
    return db.collection("users").document(guardian_uid).collection("fcm_registrations")

def notify_guardian(guardian_uid, *, kind, status, event_id, case_id=None, found_report_id=None):
    try:
        db = database()
        context = {'found_report_id': found_report_id} if found_report_id else {'case_id': case_id}
        context_id = found_report_id or case_id
        ref = db.collection('users').document(guardian_uid).collection('notifications').document(context_id + '-' + status)
        @firestore.transactional
        def record(tx):
            if not ref.get(transaction=tx).exists:
                tx.set(ref, {**context, 'event_id': event_id, 'kind': kind,
                    'status': status, 'created_at': firestore.SERVER_TIMESTAMP, 'read_at': None})
        if not ref.get().exists:
            record(db.transaction())
        logging.getLogger('uvicorn.error').info('Radd Guardian event %s T3 history_ready epoch_ms=%d', ref.id, time.time()*1000)
        delivery_queue.submit(ref.path, lambda: _deliver_guardian(guardian_uid, kind=kind,
            status=status, event_id=event_id, **context))
    except Exception as error:
        logging.getLogger('uvicorn.error').warning('Guardian event pending retry (%s)', type(error).__name__)

def _deliver_guardian(guardian_uid, *, kind, status, event_id, case_id=None, found_report_id=None):
    try:
        db = database()
        docs = [d for d in _registrations(db, guardian_uid).stream() if (d.to_dict() or {}).get("token")]
        profile = db.collection('users').document(guardian_uid).get().to_dict() or {}
        if profile.get('role') != 'guardian' or profile.get('active') is False:
            return
        now = datetime.now(timezone.utc)
        docs = [d for d in docs if d.to_dict().get('session_expires_at', 0) > now.timestamp()]
        if not docs:
            return
        account = auth.get_user(guardian_uid, app=firebase_app())
        if account.disabled:
            return
        docs = [d for d in docs if d.to_dict().get('session_auth_time', 0) >= account.tokens_valid_after_timestamp / 1000]
        context = {'found_report_id': found_report_id} if found_report_id else {'case_id': case_id}
        context_id = found_report_id or case_id
        notification = db.collection('users').document(guardian_uid).collection('notifications').document(context_id + '-' + status)
        if not notification.get().exists:
            return
        data = {"kind": kind, "status": status, **context, "event_id": event_id, "role": "guardian", "notification_id": context_id + "-" + status}
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
                try:
                    doc.reference.delete()
                except Exception:
                    pass
    except Exception as error:
        logging.getLogger('uvicorn.error').warning('Guardian FCM pending retry (%s)', type(error).__name__)


def retry_guardian_alerts():
    from google.cloud.firestore_v1.base_query import FieldFilter
    db = database()
    for user in db.collection('users').where(filter=FieldFilter('role', '==', 'guardian')).stream():
        for note in user.reference.collection('notifications').stream():
            data = note.to_dict() or {}
            if data.get('found_report_id'):
                report = db.collection('found_reports').document(data['found_report_id']).get().to_dict() or {}
                if report and data.get('status') and data.get('event_id') == report.get('event_id'):
                    delivery_queue.submit(note.reference.path, lambda uid=user.id, d=data: _deliver_guardian(uid,
                        kind='found_report', status=d['status'], found_report_id=d['found_report_id'], event_id=d['event_id']))
                continue
            case = db.collection('cases').document(data.get('case_id', '_missing')).get().to_dict() or {}
            closed = case.get('closed_at')
            if not case or case.get('scrubbed_at') or (closed and datetime.now(timezone.utc)-closed >= timedelta(hours=24)):
                continue
            if data.get('case_id') and data.get('status') and data.get('event_id'):
                delivery_queue.submit(note.reference.path, lambda uid=user.id, d=data: _deliver_guardian(uid,
                    kind=d.get('kind', 'status_update'), status=d['status'], case_id=d['case_id'], event_id=d['event_id']))
