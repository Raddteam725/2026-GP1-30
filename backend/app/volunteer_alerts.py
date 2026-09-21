"""Delivery of the shared alert intents to authenticated, enabled Volunteers.

FCM is a signal; per-user notification records (`users/{uid}/
volunteer_notifications/{case}-{suffix}`) are the durable history and what
the Volunteer app refetches after the signal. Location is foreground-only and
expires after 60 seconds without a heartbeat. Registration eligibility is the
shared app.sessions contract (valid while the account's Firebase session is);
pushes go through the shared app.delivery contract (one batch, receipts,
retry). The normal path is the immediate attempt inside the request that
committed the case change; local_jobs.retry_alerts only reconciles what FCM
never accepted.

Which Volunteers are "relevant" comes from the existing participation model,
never a broadcast to everyone:
- a NEW case (report_received / search_in_progress): every active Volunteer
  registered for the case's event -- the general alert intent's audience;
- a MATCH (match_confirmed onward): the Volunteers in `joined_by` other than
  the confirmer, who alone keeps the case;
- a CLOSED case (Guardian cancel / resolve, or Admin transfer): exactly the
  Volunteers who were told about it -- `joined_by`, `confirmed_by`, and
  anyone holding a durable notification for the case -- so it never just
  vanishes from their list without a record explaining why. A reunification
  is the confirmer's own action; the others already received Match Confirmed.
"""
import logging
import math
import time
from datetime import datetime, timezone
from firebase_admin import firestore, messaging
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import firebase_app
from .case_models import STAGES, TERMINAL_STATUSES
from .alerts import PROXIMITY_RADIUS_METERS
from .delivery import deliver
from .sessions import eligible_registrations

TEXT = {
    'en': {'general': 'A new missing-person case needs your help.', 'priority': 'A nearby missing-person case needs your help.',
           'status_update': 'A match has been found for a case you joined.', 'case_closed': 'A case you were alerted about has been closed.'},
    'ar': {'general': 'بلاغ فقدان جديد يحتاج إلى مساعدتك.', 'priority': 'بلاغ فقدان قريب يحتاج إلى مساعدتك.',
           'status_update': 'تم العثور على تطابق لحالة انضممت إلى البحث عنها.', 'case_closed': 'تم إغلاق حالة تم تنبيهك بشأنها.'},
}
# Notification record kinds as the Volunteer client reads them.
RECORD_KIND = {'general': 'new_case', 'priority': 'priority', 'status_update': 'status_update', 'case_closed': 'case_closed'}

def distance(a, b, c, d):
    lat = math.radians(c-a)
    lon = math.radians(d-b)
    h = math.sin(lat/2)**2 + math.cos(math.radians(a))*math.cos(math.radians(c))*math.sin(lon/2)**2
    return 6371000 * 2 * math.asin(min(1, math.sqrt(h)))

def _suffix(kind, status):
    # `{case}-new` / `-priority` / `-match_confirmed` are the ids the Volunteer
    # client already knows; a closure record is `{case}-{outcome}` so each
    # distinct outcome (cancelled / resolved / ...) is its own durable entry.
    return {'general': 'new', 'priority': 'priority', 'status_update': 'match_confirmed'}.get(kind, status)

def delivery(db, user, case, kind, registrations):
    """Durable record first (create-if-absent), then the immediate push to
    every eligible registration -- with zero registrations the record alone
    is written, so the history is complete even for a device that is
    currently unreachable."""
    cd = case.to_dict()
    ref = user.reference.collection('volunteer_notifications').document(case.id + '-' + _suffix(kind, cd['status']))
    @firestore.transactional
    def record(tx):
        current = ref.get(transaction=tx)
        if not current.exists:
            tx.set(ref, {'case_id': case.id, 'event_id': cd['event_id'], 'kind': RECORD_KIND[kind],
                         'status': cd['status'], 'created_at': firestore.SERVER_TIMESTAMP, 'read_at': None})
    record(db.transaction())
    if not registrations:
        return
    def build(rd):
        locale = rd.get('locale', 'en')
        text = TEXT.get(locale, TEXT['en'])[kind]
        return messaging.Message(token=rd['token'],
            notification=messaging.Notification(title='راد' if locale == 'ar' else 'Radd', body=text),
            data={'role': 'volunteer', 'case_id': case.id, 'event_id': cd['event_id'], 'kind': kind, 'status': cd['status']})
    deliver(db, ref, registrations, build, app=firebase_app())

def _volunteers(db):
    for user in db.collection('users').where(filter=FieldFilter('role', '==', 'volunteer')).stream():
        if user.to_dict().get('active') is True:
            yield user

def closure_recipients(db, case):
    """Everyone the existing model says was told about this case."""
    cd = case.to_dict() or {}
    uids = set(cd.get('joined_by') or [])
    if cd.get('confirmed_by'):
        uids.add(cd['confirmed_by'])
    for user in db.collection('users').where(filter=FieldFilter('role', '==', 'volunteer')).stream():
        if user.id in uids:
            continue
        notes = user.reference.collection('volunteer_notifications').where(filter=FieldFilter('case_id', '==', case.id)).limit(1).stream()
        if any(True for _ in notes):
            uids.add(user.id)
    return uids

def dispatch(db, case_id, *, matched=None):
    """Immediate delivery for the case's CURRENT status (derived here, so a
    retry can never send a stale kind). `matched` is accepted for older call
    sites and ignored."""
    started = time.monotonic()
    case = db.collection('cases').document(case_id).get()
    cd = case.to_dict() or {}
    status = cd.get('status')
    if status in TERMINAL_STATUSES:
        if status == 'reunited':
            return
        recipients = closure_recipients(db, case)
        for user in _volunteers(db):
            if user.id not in recipients:
                continue
            delivery(db, user, case, 'case_closed', eligible_registrations(user.reference, user.id, event_id=cd.get('event_id')))
        logging.getLogger('radd.timing').info('Radd timing: T4 volunteer dispatch case=%s status=%s recipients=%d ms=%d',
                                              case_id, status, len(recipients), int((time.monotonic()-started)*1000))
        return
    if status not in STAGES:
        return
    matched = status in STAGES[2:]
    now = datetime.now(timezone.utc)
    recipients = 0
    for user in _volunteers(db):
        if matched and (user.id not in cd.get('joined_by', []) or user.id == cd.get('confirmed_by')):
            continue
        registrations = eligible_registrations(user.reference, user.id, event_id=cd.get('event_id'))
        if not registrations:
            continue
        recipients += 1
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
    logging.getLogger('radd.timing').info('Radd timing: T4 volunteer dispatch case=%s status=%s recipients=%d ms=%d',
                                          case_id, status, recipients, int((time.monotonic()-started)*1000))

def safe_dispatch(db, case_id, *, matched=None):
    try:
        dispatch(db, case_id, matched=matched)
    except Exception as error:
        # Never roll back an already committed Guardian operation; the
        # durable records make this retryable by the reconciliation job.
        logging.getLogger(__name__).warning('Volunteer dispatch failed (%s)', type(error).__name__)
