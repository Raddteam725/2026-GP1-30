"""Persistent, event-scoped Volunteer workflow on shared Guardian registrations/cases."""
import hashlib
import secrets
from datetime import datetime, timezone
from fastapi import HTTPException, Depends, Response
from pydantic import BaseModel, ConfigDict, Field
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import bucket
from .events import active_event
from .service import normalize_photo
from .case_models import STAGES

class FoundInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    request_id: str = Field(min_length=16, max_length=128, pattern=r'^[a-zA-Z0-9-]+$')
    photo_base64: str = Field(min_length=1, max_length=11_000_000)

class MatchInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    profile_id: str = Field(pattern=r'^[a-f0-9]{64}$')

class VerifyInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    payload: str = Field(min_length=1, max_length=1024)

def key(doc):
    return hashlib.sha256(doc.reference.path.encode()).hexdigest()

def valid_id(value):
    if not value or '/' in value or len(value) > 128:
        raise HTTPException(404, detail='not_found')
    return value

class VolunteerWorkflow:
    def registrations(self):
        self.profile(require_active=True)
        event = active_event(self.db)
        # Reuses existing registration subcollections; no copied registry/index.
        for guardian in self.db.collection('users').where(filter=FieldFilter('role', '==', 'guardian')).stream():
            for person in guardian.reference.collection('individuals').where(filter=FieldFilter('event_id', '==', event.id)).stream():
                data = person.to_dict()
                if not data.get('deleting') and data.get('guardian_id') == guardian.id:
                    yield person

    def registration(self, profile_id):
        for doc in self.registrations():
            if key(doc) == profile_id:
                return doc
        raise HTTPException(404, detail='not_found')

    def eligible(self, doc):
        case_id = doc.to_dict().get('active_case_id')
        if not case_id:
            return True
        case = self.cases.document(case_id).get().to_dict() or {}
        return case.get('status') in STAGES[:2] and case.get('event_id') == doc.to_dict().get('event_id') and case.get('guardian_id') == doc.to_dict().get('guardian_id') and case.get('individual_id') == doc.id

    def public_registration(self, doc, contact=False):
        data = doc.to_dict()
        result = {'id': key(doc), **{k: data.get(k) for k in ('full_name', 'age', 'gender', 'relationship')}}
        case_id = data.get('active_case_id')
        if case_id:
            case = self.cases.document(case_id).get().to_dict() or {}
            result['case_id'] = case_id
            result['guided_report'] = case.get('guided_report')
        if contact:
            guardian = self.db.collection('users').document(data['guardian_id']).get().to_dict() or {}
            result['guardian'] = {'full_name': guardian.get('full_name'), 'phone': guardian.get('phone'), 'relationship': data.get('relationship')}
        return result

    def profiles_list(self):
        return [self.public_registration(doc) for doc in self.registrations() if self.eligible(doc)]

    def profile_detail(self, profile_id):
        doc = self.registration(profile_id)
        if not self.eligible(doc):
            raise HTTPException(404, detail='not_found')
        return self.public_registration(doc)

    def registration_photo(self, profile_id):
        doc = self.registration(profile_id)
        if not self.eligible(doc):
            raise HTTPException(404, detail='not_found')
        return self.registration_bytes(doc)

    def registration_bytes(self, doc):
        data = doc.to_dict()
        if not data:
            raise HTTPException(404, detail='not_found')
        expected = f"guardians/{data['guardian_id']}/individuals/{doc.id}/"
        path = data.get('photo_path', '')
        if not path.startswith(expected):
            raise HTTPException(404, detail='not_found')
        return bucket().blob(path).download_as_bytes()

    def found_owned(self, report_id, tx=None):
        self.profile(tx, require_active=True)
        event = active_event(self.db, tx)
        doc = self.db.collection('found_reports').document(valid_id(report_id)).get(transaction=tx)
        data = doc.to_dict() or {}
        if data.get('volunteer_uid') != self.uid or data.get('event_id') != event.id:
            raise HTTPException(404, detail='not_found')
        return doc

    def public_found(self, doc):
        data = doc.to_dict()
        result = {'id': doc.id, 'created_at': data.get('created_at'), 'ai_status': data['ai_status'],
                  'case_id': data.get('case_id'), 'matched_profile_id': data.get('matched_profile_id')}
        if data.get('case_id'):
            case = self.accessible(data['case_id'])
            state = case.to_dict()
            if state.get('confirmed_by') != self.uid:
                raise HTTPException(403, detail='confirmer_required')
            person = self.db.collection('users').document(state['guardian_id']).collection('individuals').document(state['individual_id']).get()
            if person.exists:
                person_data = self.public_registration(person, contact=True)
            else:
                person_data = {'id': data['matched_profile_id'], **data.get('matched_snapshot', {})}
                guardian = self.db.collection('users').document(state['guardian_id']).get().to_dict() or {}
                person_data['guardian'] = {'full_name': guardian.get('full_name'), 'phone': guardian.get('phone')}
            result.update(status=state['status'], person=person_data,
                          verification=({k: v for k, v in state['guardian_verification'].items() if k != 'token_hash'} if state.get('guardian_verification') else None), handed_over_at=state.get('handed_over_at'),
                          handed_over_by=state.get('handed_over_by'))
        return result

    def found_list(self):
        self.profile(require_active=True)
        event = active_event(self.db)
        docs = self.db.collection('found_reports').where(filter=FieldFilter('volunteer_uid', '==', self.uid)).stream()
        return sorted([self.public_found(d) for d in docs if d.to_dict().get('event_id') == event.id], key=lambda d: str(d['created_at']), reverse=True)

    def submit_found(self, value):
        self.profile(require_active=True)
        image = normalize_photo(value.photo_base64)
        report_id = 'FR-' + hashlib.sha256((self.uid + ':' + value.request_id).encode()).hexdigest()[:40]
        ref = self.db.collection('found_reports').document(report_id)
        existing = ref.get()
        if existing.exists:
            return self.public_found(self.found_owned(report_id))
        path = f'found/{self.uid}/{report_id}/{secrets.token_hex(16)}.jpg'
        bucket().blob(path).upload_from_string(image, content_type='image/jpeg')
        def cleanup():
            try:
                bucket().blob(path).delete()
            except Exception:
                self.db.collection('photo_cleanup').add({'path': path, 'created_at': firestore.SERVER_TIMESTAMP})
        @firestore.transactional
        def save(tx):
            self.profile(tx, require_active=True)
            event = active_event(self.db, tx)
            if ref.get(transaction=tx).exists:
                return False
            tx.set(ref, {'volunteer_uid': self.uid, 'event_id': event.id, 'photo_path': path,
                'created_at': firestore.SERVER_TIMESTAMP, 'updated_at': firestore.SERVER_TIMESTAMP,
                'ai_status': 'unavailable', 'matched_profile_id': None, 'case_id': None})
            return True
        try:
            created = save(self.db.transaction())
        except Exception:
            cleanup()
            raise
        if not created:
            cleanup()
        return self.public_found(self.found_owned(report_id))

    def found_photo(self, report_id):
        data = self.found_owned(report_id).to_dict()
        path = data.get('photo_path', '')
        if not path.startswith(f'found/{self.uid}/{report_id}/'):
            raise HTTPException(404, detail='not_found')
        return bucket().blob(path).download_as_bytes()

    def candidates(self, report_id):
        self.found_owned(report_id)
        # Explicit contract for the future model worker; zero fabricated candidates.
        return {'state': 'unavailable', 'candidates': []}

    def confirm(self, report_id, profile_id):
        found = self.found_owned(report_id)
        if found.to_dict().get('matched_profile_id') == profile_id:
            return self.public_found(found)
        person_ref = self.registration(profile_id).reference
        new_case = self.cases.document('RD-' + secrets.token_hex(6).upper())
        @firestore.transactional
        def confirm(tx):
            report = self.found_owned(report_id, tx)
            rd = report.to_dict()
            person = person_ref.get(transaction=tx)
            pd = person.to_dict() or {}
            if rd.get('matched_profile_id'):
                if rd['matched_profile_id'] == profile_id:
                    return
                raise HTTPException(409, detail='already_matched')
            if pd.get('deleting') or pd.get('event_id') != rd['event_id']:
                raise HTTPException(409, detail='profile_unavailable')
            case_id = pd.get('active_case_id')
            ref = self.cases.document(case_id) if case_id else new_case
            old = ref.get(transaction=tx)
            cd = old.to_dict() or {}
            if case_id and (cd.get('status') not in STAGES[:2] or cd.get('guardian_id') != pd['guardian_id'] or cd.get('individual_id') != person.id or cd.get('event_id') != rd['event_id']):
                raise HTTPException(409, detail='case_not_joinable')
            if not case_id and old.exists:
                raise HTTPException(409, detail='identifier_conflict')
            now = firestore.SERVER_TIMESTAMP
            if not case_id:
                # A real found report may precede a missing report. Create the shared
                # case on confirmation so the Guardian can verify and see handover.
                tx.set(ref, {'guardian_id': pd['guardian_id'], 'individual_id': person.id,
                    'individual_path': person_ref.path, 'individual_name': pd['full_name'], 'age': pd['age'],
                    'event_id': rd['event_id'], 'created_at': now, 'source': 'found_report',
                    'guided_report': None, 'status': 'match_confirmed', 'confirmed_by': self.uid,
                    'found_report_id': report_id, 'joined_by': [self.uid], 'updated_at': now,
                    'stage_timestamps': {'match_confirmed': now}})
                tx.update(person_ref, {'active_case_id': ref.id})
            else:
                tx.update(ref, {'status': 'match_confirmed', 'confirmed_by': self.uid,
                    'found_report_id': report_id, 'updated_at': now, 'stage_timestamps.match_confirmed': now})
            tx.update(report.reference, {'matched_profile_id': profile_id, 'case_id': ref.id, 'updated_at': now, 'matched_snapshot': {k: pd.get(k) for k in ('full_name', 'age', 'gender', 'relationship')}})
            for uid in set(cd.get('joined_by', [])) - {self.uid}:
                tx.set(self.db.collection('users').document(uid).collection('volunteer_notifications').document(ref.id + '-match_confirmed'),
                    {'case_id': ref.id, 'event_id': rd['event_id'], 'kind': 'status_update', 'status': 'match_confirmed', 'created_at': now, 'read_at': None})
            tx.set(self.db.collection('users').document(pd['guardian_id']).collection('notifications').document(ref.id + '-match_confirmed'),
                {'case_id': ref.id, 'event_id': rd['event_id'], 'kind': 'status_update', 'status': 'match_confirmed', 'created_at': now, 'read_at': None})
        confirm(self.db.transaction())
        return self.public_found(self.found_owned(report_id))

    def confirmed_case(self, report_id, tx=None):
        report = self.found_owned(report_id, tx)
        case_id = report.to_dict().get('case_id')
        if not case_id:
            raise HTTPException(409, detail='match_required')
        case = self.accessible(case_id, tx)
        if case.to_dict().get('confirmed_by') != self.uid or case.to_dict().get('found_report_id') != report_id:
            raise HTTPException(403, detail='confirmer_required')
        return case

    def begin_verification(self, report_id):
        @firestore.transactional
        def begin(tx):
            case = self.confirmed_case(report_id, tx)
            if case.to_dict()['status'] == 'awaiting_guardian_verification':
                return
            if case.to_dict()['status'] != 'match_confirmed':
                raise HTTPException(409, detail='invalid_transition')
            tx.update(case.reference, {'status': 'awaiting_guardian_verification', 'updated_at': firestore.SERVER_TIMESTAMP,
                'stage_timestamps.awaiting_guardian_verification': firestore.SERVER_TIMESTAMP})
        begin(self.db.transaction())
        return self.public_found(self.found_owned(report_id))

    def verify_guardian(self, report_id, payload):
        # The QR is Guardian-account-level, not per-case: the payload names WHICH
        # guardian, and this Volunteer's own current case (confirmed_case) supplies
        # the case context. A scan only proves "this account", so the association
        # to the case is re-checked here (case.guardian_id must equal the scanned
        # guardian_id) before the challenge is even looked up.
        @firestore.transactional
        def verify(tx):
            case = self.confirmed_case(report_id, tx)
            cd = case.to_dict()
            if cd['status'] != 'awaiting_guardian_verification':
                raise HTTPException(409, detail='invalid_transition')
            prefix = 'radd:guardian-verification:v1:'
            rest = payload[len(prefix):] if payload.startswith(prefix) else ''
            guardian_id, _, nonce = rest.partition(':')
            associated = bool(guardian_id and '/' not in guardian_id and guardian_id == cd['guardian_id'])
            digest = hashlib.sha256(nonce.encode()).hexdigest() if nonce else ''
            receipt = cd.get('guardian_verification') or {}
            # Same-device lost-response retry is idempotent, not a new consumption.
            if receipt.get('volunteer_uid') == self.uid and receipt.get('token_hash') == digest and nonce:
                return True
            challenge = None
            if associated and nonce:
                challenge = self.db.collection('users').document(guardian_id).collection('verification').document('current').get(transaction=tx)
            data = challenge.to_dict() if challenge else {}
            valid = bool(associated and nonce and data.get('token_hash') and secrets.compare_digest(digest, data['token_hash'])
                and data.get('guardian_id') == cd['guardian_id'] and data.get('event_id') == cd['event_id']
                and data.get('consumed_at') is None and isinstance(data.get('expires_at'), datetime)
                and data['expires_at'] > datetime.now(timezone.utc))
            if not valid:
                tx.update(case.reference, {'guardian_verification': None})
                return False
            now = firestore.SERVER_TIMESTAMP
            tx.update(challenge.reference, {'consumed_at': now, 'consumed_by': self.uid})
            tx.update(case.reference, {'guardian_verification': {'method': 'qr', 'volunteer_uid': self.uid,
                'guardian_id': cd['guardian_id'], 'case_id': case.id, 'verified_at': now, 'token_hash': digest}, 'updated_at': now})
            return True
        return {'verified': verify(self.db.transaction()), 'report': self.public_found(self.found_owned(report_id))}

    def handover_found(self, report_id):
        @firestore.transactional
        def handover(tx):
            case = self.confirmed_case(report_id, tx)
            cd = case.to_dict()
            person = self.db.collection('users').document(cd['guardian_id']).collection('individuals').document(cd['individual_id']).get(transaction=tx)
            proof = cd.get('guardian_verification') or {}
            if cd['status'] == 'reunited' and cd.get('handed_over_by') == self.uid:
                return
            if cd['status'] != 'awaiting_guardian_verification' or proof.get('method') != 'qr' or proof.get('volunteer_uid') != self.uid or proof.get('case_id') != case.id or proof.get('guardian_id') != cd['guardian_id']:
                raise HTTPException(409, detail='guardian_verification_required')
            now = firestore.SERVER_TIMESTAMP
            tx.update(case.reference, {'status': 'reunited', 'updated_at': now, 'stage_timestamps.reunited': now,
                'handed_over_at': now, 'handed_over_by': self.uid})
            if person.exists and person.to_dict().get('active_case_id') == case.id:
                tx.update(person.reference, {'active_case_id': None, 'updated_at': now})
            tx.set(self.db.collection('users').document(cd['guardian_id']).collection('notifications').document(case.id + '-reunited'),
                {'case_id': case.id, 'event_id': cd['event_id'], 'kind': 'status_update', 'status': 'reunited', 'created_at': now, 'read_at': None})
        handover(self.db.transaction())
        return self.public_found(self.found_owned(report_id))

    def notifications_list(self):
        self.profile(require_active=True)
        event = active_event(self.db)
        collection = self.user.collection('volunteer_notifications')
        # Materialize actual event case notifications lazily, using stable IDs and
        # transactional create-if-absent. No fake records, no Guardian changes.
        for case in self.cases.where(filter=FieldFilter('event_id', '==', event.id)).stream():
            if case.to_dict().get('status') not in STAGES[:2]:
                continue
            ref = collection.document(case.id + '-new')
            @firestore.transactional
            def create(tx):
                self.profile(tx, require_active=True)
                current = case.reference.get(transaction=tx)
                notification = ref.get(transaction=tx)
                if notification.exists or current.to_dict().get('status') not in STAGES[:2]:
                    return
                tx.set(ref, {'case_id': case.id, 'event_id': event.id, 'kind': 'new_case',
                    'status': current.to_dict()['status'], 'created_at': firestore.SERVER_TIMESTAMP, 'read_at': None})
            create(self.db.transaction())
        return [{'id': d.id, **d.to_dict()} for d in collection.stream() if d.to_dict().get('event_id') == event.id]

    def notification_read(self, notification_id):
        self.profile(require_active=True)
        ref = self.user.collection('volunteer_notifications').document(valid_id(notification_id))
        @firestore.transactional
        def mark(tx):
            self.profile(tx, require_active=True)
            doc = ref.get(transaction=tx)
            if not doc.exists:
                raise HTTPException(404, detail='not_found')
            if doc.to_dict().get('read_at') is None:
                tx.update(ref, {'read_at': firestore.SERVER_TIMESTAMP})
        mark(self.db.transaction())

def register_workflow(router, service):
    @router.get('/cases/{case_id}')
    def case_details(case_id: str, s=Depends(service)):
        return s.public(s.accessible(case_id))
    @router.get('/profiles')
    def profiles(s=Depends(service)):
        return s.profiles_list()
    @router.get('/profiles/{profile_id}')
    def profile_detail(profile_id: str, s=Depends(service)):
        return s.profile_detail(profile_id)
    @router.get('/profiles/{profile_id}/photo')
    def profile_photo(profile_id: str, s=Depends(service)):
        return Response(s.registration_photo(profile_id), media_type='image/jpeg')
    @router.get('/found-reports')
    def reports(s=Depends(service)):
        return s.found_list()
    @router.post('/found-reports', status_code=201)
    def submit(value: FoundInput, s=Depends(service)):
        return s.submit_found(value)
    @router.get('/found-reports/{report_id}')
    def report(report_id: str, s=Depends(service)):
        return s.public_found(s.found_owned(report_id))
    @router.get('/found-reports/{report_id}/photo')
    def found_photo(report_id: str, s=Depends(service)):
        return Response(s.found_photo(report_id), media_type='image/jpeg')
    @router.get('/found-reports/{report_id}/registered-photo')
    def matched_photo(report_id: str, s=Depends(service)):
        case = s.confirmed_case(report_id).to_dict()
        doc = s.db.collection('users').document(case['guardian_id']).collection('individuals').document(case['individual_id']).get()
        return Response(s.registration_bytes(doc), media_type='image/jpeg')
    @router.get('/found-reports/{report_id}/candidates')
    def candidates(report_id: str, s=Depends(service)):
        return s.candidates(report_id)
    @router.post('/found-reports/{report_id}/confirm-match')
    def confirm(report_id: str, value: MatchInput, s=Depends(service)):
        return s.confirm(report_id, value.profile_id)
    @router.post('/found-reports/{report_id}/begin-verification')
    def begin(report_id: str, s=Depends(service)):
        return s.begin_verification(report_id)
    @router.post('/found-reports/{report_id}/verify')
    def verify(report_id: str, value: VerifyInput, s=Depends(service)):
        return s.verify_guardian(report_id, value.payload)
    @router.post('/found-reports/{report_id}/handover')
    def handover(report_id: str, s=Depends(service)):
        return s.handover_found(report_id)
    @router.get('/notifications')
    def notifications(s=Depends(service)):
        return s.notifications_list()
    @router.put('/notifications/{notification_id}/read', status_code=204)
    def read(notification_id: str, s=Depends(service)):
        s.notification_read(notification_id)
        return Response(status_code=204)
