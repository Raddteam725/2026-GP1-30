"""Delivery of the shared alert intents to authenticated, enabled Volunteers.

FCM is a delivery channel; per-user notification records are durable history.
Location is foreground-only and expires after 60 seconds without a heartbeat.
FCM registration eligibility expires with the verified Firebase ID token.
"""
import hashlib
import math
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore, messaging
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import firebase_app
from .case_models import STAGES
from .alerts import PROXIMITY_RADIUS_METERS

TEXT = {
    'en': {'general': 'A new missing-person case needs your help.', 'priority': 'A nearby missing-person case needs your help.', 'status_update': 'A match has been found for a case you joined.'},
    'ar': {'general': 'بلاغ فقدان جديد يحتاج إلى مساعدتك.', 'priority': 'بلاغ فقدان قريب يحتاج إلى مساعدتك.', 'status_update': 'تم العثور على تطابق لحالة انضممت إلى البحث عنها.'},
}

def distance(a, b, c, d):
    lat = math.radians(c-a)
    lon = math.radians(d-b)
    h = math.sin(lat/2)**2 + math.cos(math.radians(a))*math.cos(math.radians(c))*math.sin(lon/2)**2
    return 6371000 * 2 * math.asin(min(1, math.sqrt(h)))

def delivery(db, user, case, kind, registrations):
    cd = case.to_dict()
    suffix = {'general': 'new', 'priority': 'priority', 'status_update': 'match_confirmed'}[kind]
    ref = user.reference.collection('volunteer_notifications').document(case.id + '-' + suffix)
    @firestore.transactional
    def record(tx):
        current = ref.get(transaction=tx)
        if not current.exists:
            tx.set(ref, {'case_id': case.id, 'event_id': cd['event_id'], 'kind': 'new_case' if kind == 'general' else kind,
                         'status': cd['status'], 'created_at': firestore.SERVER_TIMESTAMP, 'read_at': None})
    record(db.transaction())
    for registration in registrations:
        rd = registration.to_dict()
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
            continue
        locale = rd.get('locale', 'en')
        text = TEXT.get(locale, TEXT['en'])[kind]
        try:
            messaging.send(messaging.Message(token=rd['token'],
                notification=messaging.Notification(title='راد' if locale == 'ar' else 'Radd', body=text),
                data={'role': 'volunteer', 'case_id': case.id, 'event_id': cd['event_id'], 'kind': kind, 'status': cd['status']}), app=firebase_app())
            receipt.set({'sent_at': firestore.SERVER_TIMESTAMP})
        except messaging.UnregisteredError:
            receipt.delete()
            registration.reference.delete()
        except Exception:
            receipt.delete()
            continue  # Pending delivery remains retryable; never claim delivery.

def dispatch(db, case_id, *, matched=False):
    case = db.collection('cases').document(case_id).get()
    cd = case.to_dict() or {}
    if cd.get('status') not in (STAGES[2:] if matched else STAGES[:2]):
        return
    now = datetime.now(timezone.utc)
    for user in db.collection('users').where(filter=FieldFilter('role', '==', 'volunteer')).stream():
        if user.to_dict().get('active') is not True:
            continue
        if matched and (user.id not in cd.get('joined_by', []) or user.id == cd.get('confirmed_by')):
            continue
        registrations = [r for r in user.reference.collection('fcm_registrations').stream()
                         if r.to_dict().get('event_id') == cd.get('event_id') and r.to_dict().get('session_expires_at', 0) > now.timestamp()]
        if not registrations:
            continue
        delivery(db, user, case, 'status_update' if matched else 'general', registrations)
        guided = cd.get('guided_report') or {}
        if matched or guided.get('same_location') is not True or guided.get('latitude') is None or guided.get('longitude') is None:
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

def safe_dispatch(db, case_id, *, matched=False):
    try:
        dispatch(db, case_id, matched=matched)
    except Exception:
        pass  # Never roll back an already committed Guardian operation.
