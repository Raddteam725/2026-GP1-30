"""Delivery of the shared alert intents to authenticated, enabled Volunteers.

FCM is a delivery channel; per-user notification records are durable history.
Location is available during authorized participation; estimates expire after 60 seconds.
FCM registration eligibility expires with the verified Firebase ID token.
"""
import logging
import math
import time
from datetime import datetime, timedelta, timezone
from firebase_admin import auth, firestore, messaging
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import firebase_app
from . import delivery_queue
from .case_models import STAGES
from .alerts import PROXIMITY_RADIUS_METERS
from .volunteer_access import eligible_for_event
from .volunteer_consent import current as consent_current

TEXT = {
    'en': {'general': 'A new missing-person case needs your help.', 'priority': 'A nearby missing-person case needs your help.', 'status_update': 'A match has been found for a case you joined.', 'cancelled': 'The guardian cancelled this missing-person case.', 'resolved': 'The guardian found the individual and resolved this case.', 'reunited': 'The individual has been reunited with their guardian.'},
    'ar': {'general': 'بلاغ فقدان جديد يحتاج إلى مساعدتك.', 'priority': 'بلاغ فقدان قريب يحتاج إلى مساعدتك.', 'status_update': 'تم العثور على تطابق لحالة انضممت إلى البحث عنها.', 'cancelled': 'ألغى ولي الأمر بلاغ الفقدان لهذه الحالة.', 'resolved': 'عثر ولي الأمر على الشخص وأغلق الحالة.', 'reunited': 'تم تسليم الشخص إلى ولي أمره بعد التحقق.'},
}

def distance(a, b, c, d):
    lat = math.radians(c-a)
    lon = math.radians(d-b)
    h = math.sin(lat/2)**2 + math.cos(math.radians(a))*math.cos(math.radians(c))*math.sin(lon/2)**2
    return 6371000 * 2 * math.asin(min(1, math.sqrt(h)))

def delivery(db, user, case, kind, registrations):
    cd = case.to_dict()
    suffix = {'general': 'new', 'priority': 'priority', 'status_update': 'match_confirmed'}.get(kind, kind)
    ref = user.reference.collection('volunteer_notifications').document(case.id + '-' + suffix)
    @firestore.transactional
    def record(tx):
        current = ref.get(transaction=tx)
        if not current.exists:
            tx.set(ref, {'case_id': case.id, 'event_id': cd['event_id'], 'kind': 'new_case' if kind == 'general' else kind,
                         'status': cd['status'], 'created_at': firestore.SERVER_TIMESTAMP, 'read_at': None})
    record(db.transaction())
    logging.getLogger("uvicorn.error").info("Radd event %s T3 history_ready epoch_ms=%d", ref.id, time.time()*1000)
    for registration in registrations:
        delivery_queue.submit(ref.path + '/' + registration.id,
            lambda registration=registration: _send_registration(db, user, case, kind, ref, registration))

def _send_registration(db, user, case, kind, ref, registration):
    cd = case.to_dict()
    latest = case.reference.get().to_dict() or {}
    if not eligible_for_event(db, user.id, latest.get('event_id')):
        return
    if not latest or latest.get('scrubbed_at') or not ref.get().exists:
        return
    if kind in ('general', 'priority') and latest.get('status') not in STAGES[:2]:
        return
    fresh = registration.reference.get()
    rd = fresh.to_dict() or {}
    history = ref.get().to_dict() or {}
    registered_at = rd.get('created_at')
    event_at = history.get('created_at')
    # Token rotation/re-login must not deliver historical events to a new
    # registration. Existing failed deliveries remain retryable on their device.
    if history.get('read_at') or (isinstance(registered_at, datetime) and
            isinstance(event_at, datetime) and registered_at > event_at):
        return
    profile = user.reference.get().to_dict() or {}
    if (not fresh.exists or profile.get('role') != 'volunteer' or profile.get('active') is not True or not consent_current(profile)
            or rd.get('event_id') != latest.get('event_id')
            or rd.get('session_expires_at', 0) <= datetime.now(timezone.utc).timestamp()):
        return
    try:
        account = auth.get_user(user.id, app=firebase_app())
        if account.disabled or rd.get('session_auth_time', 0) < account.tokens_valid_after_timestamp / 1000:
            return
    except Exception as error:
        logging.getLogger('uvicorn.error').warning('Volunteer session check pending retry (%s)', type(error).__name__)
        return

    receipt = ref.collection('deliveries').document(registration.id)
    @firestore.transactional
    def claim(tx):
        current = receipt.get(transaction=tx).to_dict() or {}
        now = datetime.now(timezone.utc)
        if current.get('sent_at') or current.get('lease_until', now) > now:
            return False
        tx.set(receipt, {'lease_until': now + timedelta(seconds=60)})
        return True
    if not claim(db.transaction()):
        return
    locale = rd.get('locale', 'en')
    text = TEXT.get(locale, TEXT['en'])[kind]
    try:
        started = time.monotonic()
        logging.getLogger("uvicorn.error").info("Radd event %s T4 fcm_start epoch_ms=%d", ref.id, time.time()*1000)
        messaging.send(messaging.Message(token=rd['token'],
            notification=messaging.Notification(title='راد' if locale == 'ar' else 'Radd', body=text),
            data={'role': 'volunteer', 'case_id': case.id, 'event_id': cd['event_id'], 'kind': kind, 'status': cd['status'], 'notification_id': ref.id},
            android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(tag=ref.id, channel_id='radd_volunteer_alerts'))), app=firebase_app())
        logging.getLogger("uvicorn.error").info("Radd event %s T5 fcm_accepted epoch_ms=%d elapsed_ms=%d", ref.id, time.time()*1000, (time.monotonic()-started)*1000)
        receipt.set({'sent_at': firestore.SERVER_TIMESTAMP})
    except messaging.UnregisteredError:
        receipt.delete()
        registration.reference.delete()
    except Exception as error:
        logging.getLogger("uvicorn.error").warning("Radd event %s FCM failed (%s)", ref.id, type(error).__name__)
        receipt.delete()
        return  # Pending delivery remains retryable; never claim delivery.

def dispatch(db, case_id, *, matched=False, recipient=None):
    case = db.collection('cases').document(case_id).get()
    cd = case.to_dict() or {}
    status = cd.get('status')
    terminal = status in ('cancelled', 'resolved', 'reunited')
    closed_at = cd.get('closed_at')
    if cd.get('scrubbed_at') or (terminal and isinstance(closed_at, datetime) and
            datetime.now(timezone.utc) - closed_at >= timedelta(hours=24)):
        return  # Never recreate history after the existing retention deadline.
    if not terminal and status not in (STAGES[2:] if matched else STAGES[:2]):
        return
    now = datetime.now(timezone.utc)
    users = [db.collection('users').document(recipient).get()] if recipient else db.collection('users').where(filter=FieldFilter('role', '==', 'volunteer')).stream()
    for user in users:
        if (user.to_dict() or {}).get('role') != 'volunteer' or user.to_dict().get('active') is not True or not consent_current(user.to_dict()):
            continue
        if not eligible_for_event(db, user.id, cd.get('event_id')):
            continue
        if not terminal and matched and (user.id not in cd.get('joined_by', []) or user.id == cd.get('confirmed_by')):
            continue
        if terminal and user.id not in cd.get('joined_by', []) and user.id != cd.get('confirmed_by'):
            previous = user.reference.collection('volunteer_notifications').where(filter=FieldFilter('case_id', '==', case.id)).limit(1)
            if not list(previous.stream()):
                continue
        registrations = [r for r in user.reference.collection('fcm_registrations').stream()
                         if r.to_dict().get('event_id') == cd.get('event_id') and r.to_dict().get('session_expires_at', 0) > now.timestamp()]
        logging.getLogger("uvicorn.error").info("Radd event %s eligibility active_devices=%d epoch_ms=%d", case.id, len(registrations), time.time()*1000)
        # History is durable even with notifications denied or no current device.
        delivery(db, user, case, status if terminal else 'status_update' if matched else 'general', registrations)
        guided = cd.get('guided_report') or {}
        if terminal or matched or guided.get('same_location') is not True or guided.get('latitude') is None or guided.get('longitude') is None:
            continue
        nearby = []
        for registration in registrations:
            loc = registration.to_dict().get('location') or {}
            at = loc.get('at')
            if not isinstance(at, datetime) or (now-at).total_seconds() > 60:
                continue
            if distance(loc['latitude'], loc['longitude'], guided['latitude'], guided['longitude']) <= PROXIMITY_RADIUS_METERS:
                nearby.append(registration)
        if nearby:
            # One case, a separate priority notification, never a priority case.
            intent = db.collection('alerts').document(case.id + '-priority-' + user.id)
            intent.set({'case_id': case.id, 'event_id': cd['event_id'], 'kind': 'priority',
                        'recipient_volunteer_id': user.id, 'proximity_eligible': True,
                        'status': cd['status'], 'delivered': False,
                        'distance_meters': min(distance(r.to_dict()['location']['latitude'], r.to_dict()['location']['longitude'], guided['latitude'], guided['longitude']) for r in nearby),
                        'created_at': firestore.SERVER_TIMESTAMP}, merge=True)
            delivery(db, user, case, 'priority', nearby)

def safe_dispatch(db, case_id, *, matched=False, recipient=None):
    try:
        dispatch(db, case_id, matched=matched, recipient=recipient)
    except Exception as error:
        logging.getLogger(__name__).warning('Volunteer delivery pending retry (%s)', type(error).__name__)
        # Never roll back an already committed Guardian operation.
