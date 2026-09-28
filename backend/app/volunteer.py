"""Volunteer access to the existing users and shared cases; no client-owned identity."""
from fastapi import APIRouter, Depends, HTTPException, Response
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import identity, database, bucket
from .case_models import STAGES
from .push import notify_guardian
from .service import photo_expired, GuardianService
from .models import FcmRegistration, FcmUnregister
from .volunteer_alerts import safe_dispatch
from .alerts import PROXIMITY_RADIUS_METERS
from . import volunteer_consent
from .volunteer_access import event_access, require_event
from pydantic import BaseModel, Field, ConfigDict
import hashlib
import time
import logging
from datetime import datetime, timedelta, timezone
from .volunteer_workflow import VolunteerWorkflow, register_workflow, key

JOINABLE = STAGES[:2]

class VolunteerDevice(FcmRegistration):
    latitude: float | None = Field(default=None, ge=-90, le=90, allow_inf_nan=False)
    longitude: float | None = Field(default=None, ge=-180, le=180, allow_inf_nan=False)

class VolunteerService(VolunteerWorkflow):
    def participation_event(self, tx=None):
        return require_event(self.db, self.uid, tx)

    def __init__(self, token):
        self.token, self.uid = token, token['uid']
        self.db = database()
        self.user = self.db.collection('users').document(self.uid)
        self.cases = self.db.collection('cases')

    def profile(self, tx=None, require_active=True, require_assignment=True, require_consent=True):
        data = self.user.get(transaction=tx).to_dict() or {}
        if data.get('role') != 'volunteer' or self.token.get('role') not in (None, 'volunteer'):
            raise HTTPException(403, detail='volunteer_required')
        if not isinstance(data.get('active'), bool) or not all(isinstance(data.get(k), str) and data[k].strip() for k in ('full_name', 'volunteer_id')):
            raise HTTPException(403, detail='volunteer_profile_incomplete')
        if require_active and data['active'] is not True:
            raise HTTPException(403, detail='volunteer_inactive')
        if require_consent and not volunteer_consent.current(data):
            raise HTTPException(403, detail='volunteer_consent_required')
        access = event_access(self.db, self.uid, tx) if require_active and volunteer_consent.current(data) else {'event_id': None, 'assigned': False}
        if require_assignment and not access['assigned']:
            raise HTTPException(403, detail='event_access_required')
        return {'uid': self.uid, **volunteer_consent.state(data), **access, 'proximity_radius_meters': PROXIMITY_RADIUS_METERS,
                **{k: data.get(k) for k in ('full_name', 'email', 'phone', 'volunteer_id', 'active')}}

    def register_device(self, value):
        self.profile()
        event = self.participation_event()
        ref = self.user.collection('fcm_registrations').document(hashlib.sha256(value.token.encode()).hexdigest())
        previous = ref.get().to_dict() or {}
        if not previous:
            # Cross-account token cleanup is required on registration, not on
            # every foreground location heartbeat for the same owned device.
            GuardianService.register_fcm_token(self, value.token, value.locale)
        location = None
        if value.latitude is not None and value.longitude is not None:
            location = {'latitude': value.latitude, 'longitude': value.longitude, 'at': firestore.SERVER_TIMESTAMP}
        ref.update({'locale': value.locale, 'updated_at': firestore.SERVER_TIMESTAMP, 'event_id': event.id, 'session_expires_at': self.token.get('exp', 0), 'session_auth_time': self.token.get('auth_time', 0), 'location': location})
        # Registration renews eligibility only; history is not a new event.
        return {'registered': True}

    def unregister_device(self, value):
        # Unregistration may be needed after deactivation; only this UID's device.
        self.profile(require_active=False, require_assignment=False, require_consent=False)
        ref = self.user.collection('fcm_registrations').document(hashlib.sha256(value.token.encode()).hexdigest())
        ref.delete()
        return {'unregistered': True}

    def visible(self, data):
        return data.get('status') in JOINABLE or (
            data.get('status') in STAGES[2:] and data.get('confirmed_by') == self.uid)

    def public(self, doc):
        data = doc.to_dict()
        guardian_id, person_id = data.get('guardian_id'), data.get('individual_id')
        person = {}
        if guardian_id and person_id and '/' not in guardian_id and '/' not in person_id:
            person_doc = self.db.collection('users').document(guardian_id).collection('individuals').document(person_id).get()
            person = person_doc.to_dict() or {}
        # No contact information, private paths, other volunteers' identities or QR challenges.
        return {'id': doc.id, 'photo_available': bool(person.get('photo_path')) and not photo_expired(person, self.db, case_context=True), 'profile_id': key(person_doc) if person else None, 'gender': person.get('gender'), **{k: data.get(k) for k in (
            'individual_id', 'individual_name', 'age', 'status', 'created_at',
            'updated_at', 'stage_timestamps', 'guided_report')},
            'joined': self.uid in data.get('joined_by', []),
            'confirmed_by_me': data.get('confirmed_by') == self.uid}

    def list(self, mine=False):
        self.profile(require_active=True)
        event = self.participation_event()
        docs = self.cases.where(filter=FieldFilter('event_id', '==', event.id)).stream()
        result = []
        for doc in docs:
            data = doc.to_dict()
            joined = self.uid in data.get('joined_by', [])
            include = (joined if data.get('status') in JOINABLE else data.get('confirmed_by') == self.uid) if mine else (data.get('status') in JOINABLE and not joined)
            if include and self.visible(data):
                result.append(self.public(doc))
        return sorted(result, key=lambda item: str(item['created_at']), reverse=True)

    def accessible(self, case_id, tx=None):
        if not case_id or '/' in case_id:
            raise HTTPException(404, detail='not_found')
        self.profile(tx, require_active=True)
        event = self.participation_event(tx)
        doc = self.cases.document(case_id).get(transaction=tx)
        data = doc.to_dict() or {}
        if data.get('event_id') != event.id or not self.visible(data):
            raise HTTPException(404, detail='not_found')
        return doc

    def case_state(self, case_id):
        """Minimal authoritative outcome; closure never grants private detail access."""
        self.profile(require_active=True)
        event = self.participation_event()
        if not case_id or '/' in case_id:
            raise HTTPException(404, detail='not_found')
        data = self.cases.document(case_id).get().to_dict() or {}
        closed = data.get('closed_at')
        if (data.get('event_id') != event.id or data.get('scrubbed_at') or
                (isinstance(closed, datetime) and datetime.now(timezone.utc) - closed >= timedelta(hours=24))):
            raise HTTPException(404, detail='not_found')
        if not self.visible(data) and self.uid not in data.get('joined_by', []):
            history = self.user.collection('volunteer_notifications').where(
                filter=FieldFilter('case_id', '==', case_id)).limit(1)
            if not list(history.stream()):
                raise HTTPException(404, detail='not_found')
        return {'id': case_id, 'status': data['status']}

    def start_search(self, case_id):
        push = {}
        @firestore.transactional
        def join(tx):
            push.clear()  # Firestore may retry after another Volunteer starts first.
            doc = self.accessible(case_id, tx)
            data = doc.to_dict()
            if data['status'] not in JOINABLE:
                raise HTTPException(409, detail='case_not_joinable')
            joined = data.get('joined_by', [])
            if self.uid in joined:
                return
            # The document read participates in the transaction: conflicting writes retry.
            update = {'joined_by': [*joined, self.uid]}
            if data['status'] == 'report_received':
                now = firestore.SERVER_TIMESTAMP
                update.update(status='search_in_progress', updated_at=now)
                update['stage_timestamps.search_in_progress'] = now
                # The first Volunteer to start searching moves the case to
                # Search in Progress -- a Guardian-visible status change, so
                # the Guardian gets the same notification record (and push)
                # as every other status update. Later joins change nothing
                # the Guardian sees and notify nobody.
                tx.set(self.db.collection('users').document(data['guardian_id']).collection('notifications').document(case_id + '-search_in_progress'),
                    {'case_id': case_id, 'event_id': data['event_id'], 'kind': 'status_update', 'status': 'search_in_progress', 'created_at': now, 'read_at': None})
                push.update(guardian_id=data['guardian_id'], event_id=data['event_id'])
            tx.update(doc.reference, update)
        join(self.db.transaction())
        if push:
            logging.getLogger('uvicorn.error').info('Radd event %s-search_in_progress T2 committed epoch_ms=%d', case_id, time.time()*1000)
            try:
                notify_guardian(push['guardian_id'], kind='status_update', status='search_in_progress',
                    case_id=case_id, event_id=push['event_id'])
            except Exception:
                pass
        return self.public(self.accessible(case_id))

    def photo(self, case_id):
        data = self.accessible(case_id).to_dict()
        # Construct the registration reference from its server-owned case relationship.
        guardian_id, person_id = data.get('guardian_id'), data.get('individual_id')
        if not guardian_id or not person_id or '/' in guardian_id or '/' in person_id:
            raise HTTPException(404, detail='not_found')
        person = self.db.collection('users').document(guardian_id).collection('individuals').document(person_id).get().to_dict() or {}
        if photo_expired(person, self.db, case_context=True):
            raise HTTPException(404, detail='photo_expired')
        path = person.get('photo_path', '')
        if person.get('guardian_id') != guardian_id or person.get('deleting') or not path.startswith(f'guardians/{guardian_id}/individuals/{person_id}/'):
            raise HTTPException(404, detail='not_found')
        return bucket().blob(path).download_as_bytes()

router = APIRouter(prefix='/v1/volunteer', tags=['Volunteer'])
def service(token=Depends(identity)):
    return VolunteerService(token)

@router.put('/fcm-registrations')
def register_device(value: VolunteerDevice, s=Depends(service)):
    return s.register_device(value)

@router.post('/fcm-registrations/unregister')
def unregister_device(value: FcmUnregister, s=Depends(service)):
    return s.unregister_device(value)

@router.get('')
def profile(s=Depends(service)):
    return s.profile(require_assignment=False, require_consent=False)

@router.post('/consent')
def accept_consent(value: volunteer_consent.ConsentInput, s=Depends(service)):
    return volunteer_consent.accept(s, value)

@router.get('/cases/available')
def available(s=Depends(service)):
    return s.list()

@router.get('/cases/mine')
def mine(s=Depends(service)):
    return s.list(mine=True)

@router.post('/cases/{case_id}/start-search')
def start_search(case_id: str, s=Depends(service)):
    return s.start_search(case_id)

@router.get('/cases/{case_id}/photo')
def photo(case_id: str, s=Depends(service)):
    return Response(content=s.photo(case_id), media_type='image/jpeg', headers={'Cache-Control': 'no-store'})

@router.get('/cases/{case_id}/state')
def case_state(case_id: str, s=Depends(service)):
    return s.case_state(case_id)

register_workflow(router, service)
