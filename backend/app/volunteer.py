"""Volunteer access to the existing users and shared cases; no client-owned identity."""
from fastapi import APIRouter, Depends, HTTPException, Response
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import identity, database, bucket
from .events import active_event
from .case_models import STAGES
from .push import notify_guardian
from .service import photo_expired
from .volunteer_workflow import VolunteerWorkflow, register_workflow, key

JOINABLE = STAGES[:2]

class VolunteerService(VolunteerWorkflow):
    def __init__(self, token):
        self.token, self.uid = token, token['uid']
        self.db = database()
        self.user = self.db.collection('users').document(self.uid)
        self.cases = self.db.collection('cases')

    def profile(self, tx=None, require_active=False):
        data = self.user.get(transaction=tx).to_dict() or {}
        if data.get('role') != 'volunteer' or self.token.get('role') not in (None, 'volunteer'):
            raise HTTPException(403, detail='volunteer_required')
        if not isinstance(data.get('active'), bool) or not all(isinstance(data.get(k), str) and data[k].strip() for k in ('full_name', 'volunteer_id')):
            raise HTTPException(403, detail='volunteer_profile_incomplete')
        if require_active and data['active'] is not True:
            raise HTTPException(403, detail='volunteer_inactive')
        return {'uid': self.uid, **{k: data.get(k) for k in ('full_name', 'email', 'phone', 'volunteer_id', 'active')}}

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
        return {'id': doc.id, 'profile_id': key(person_doc) if person else None, 'gender': person.get('gender'), **{k: data.get(k) for k in (
            'individual_id', 'individual_name', 'age', 'status', 'created_at',
            'updated_at', 'stage_timestamps', 'guided_report')},
            'joined': self.uid in data.get('joined_by', []),
            'confirmed_by_me': data.get('confirmed_by') == self.uid}

    def list(self, mine=False):
        self.profile(require_active=True)
        event = active_event(self.db)
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
        event = active_event(self.db, tx)
        doc = self.cases.document(case_id).get(transaction=tx)
        data = doc.to_dict() or {}
        if data.get('event_id') != event.id or not self.visible(data):
            raise HTTPException(404, detail='not_found')
        return doc

    def start_search(self, case_id):
        push = {}
        @firestore.transactional
        def join(tx):
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
        if photo_expired(person):
            raise HTTPException(404, detail='photo_expired')
        path = person.get('photo_path', '')
        if person.get('guardian_id') != guardian_id or person.get('deleting') or not path.startswith(f'guardians/{guardian_id}/individuals/{person_id}/'):
            raise HTTPException(404, detail='not_found')
        return bucket().blob(path).download_as_bytes()

router = APIRouter(prefix='/v1/volunteer', tags=['Volunteer'])
def service(token=Depends(identity)):
    return VolunteerService(token)

@router.get('')
def profile(s=Depends(service)):
    return s.profile()

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

register_workflow(router, service)
