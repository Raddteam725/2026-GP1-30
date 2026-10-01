"""Persistent, event-scoped Volunteer workflow on shared Guardian registrations/cases."""
import hashlib
import secrets
import logging
import time
from datetime import datetime, timezone
from fastapi import HTTPException, Depends, Response
from pydantic import BaseModel, ConfigDict, Field, AliasChoices
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.api_core.exceptions import NotFound
from .firebase import bucket
from .service import normalize_photo, photo_expired
from .case_models import STAGES, age_group
from . import found_reports as found_lifecycle
from .push import notify_guardian
from .volunteer_alerts import safe_dispatch

class FoundInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    request_id: str = Field(min_length=16, max_length=128, pattern=r'^[a-zA-Z0-9-]+$')
    photo_base64: str = Field(min_length=1, max_length=11_000_000)

class ManualFoundInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    request_id: str = Field(min_length=16, max_length=128, pattern=r'^[a-zA-Z0-9-]+$')
    profile_id: str = Field(pattern=r'^[a-f0-9]{64}$')

class MatchInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    profile_id: str = Field(pattern=r'^[a-f0-9]{64}$')

class VerifyInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    payload: str = Field(min_length=1, max_length=1024)

class IdentifierVerifyInput(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    # The real reunification identifier displayed by the signed-in Guardian.
    # Preserve the case_id input alias for existing Missing Case clients.
    case_id: str = Field(min_length=1, max_length=128, pattern=r'^[^/]+$', validation_alias=AliasChoices('identifier', 'case_id'))

def key(doc):
    return hashlib.sha256(doc.reference.path.encode()).hexdigest()

def valid_id(value):
    if not value or '/' in value or len(value) > 128:
        raise HTTPException(404, detail='not_found')
    return value

class VolunteerWorkflow:
    def registrations(self):
        self.profile(require_active=True)
        event = self.participation_event()
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
        if photo_expired(doc.to_dict(), self.db):
            return False
        case_id = doc.to_dict().get('active_case_id')
        if not case_id:
            return True
        case = self.cases.document(case_id).get().to_dict() or {}
        return case.get('status') in STAGES[:2] and case.get('event_id') == doc.to_dict().get('event_id') and case.get('guardian_id') == doc.to_dict().get('guardian_id') and case.get('individual_id') == doc.id

    def public_registration(self, doc, contact=False):
        data = doc.to_dict()
        result = {'id': key(doc), **{k: data.get(k) for k in ('full_name', 'age', 'gender', 'relationship', 'relationship_other')}}
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

    def profile_detail(self, profile_id, found_report_id=None, case_id=None):
        doc = self.registration(profile_id)
        if not self.eligible(doc):
            raise HTTPException(404, detail='not_found')
        contact = False
        if found_report_id:
            report = self.found_owned(found_report_id).to_dict()
            if report.get('ended') or report.get('matched_profile_id'):
                raise HTTPException(409, detail='identification_unavailable')
            # Selection is comparison only; contact follows explicit confirmation.
        if case_id:
            case = self.accessible(valid_id(case_id)).to_dict()
            data = doc.to_dict()
            if (case.get('status') not in STAGES[:2]
                    or case_id != data.get('active_case_id')
                    or case.get('guardian_id') != data.get('guardian_id')
                    or case.get('individual_id') != doc.id):
                raise HTTPException(404, detail='not_found')
            # Case browsing does not establish confirmed identity.
        return {**self.public_registration(doc, contact=contact),
                'confirmation_available': bool(found_report_id)}

    def registration_photo(self, profile_id):
        doc = self.registration(profile_id)
        if not self.eligible(doc):
            raise HTTPException(404, detail='not_found')
        return self.registration_bytes(doc)

    def registration_bytes(self, doc, report_id=None):
        data = doc.to_dict()
        if not data:
            raise HTTPException(404, detail='not_found')
        held = found_lifecycle.identified_report(self.db, data) if report_id else None
        if photo_expired(data, self.db) and (held is None or held.id != report_id):
            raise HTTPException(404, detail='photo_expired')
        expected = f"guardians/{data['guardian_id']}/individuals/{doc.id}/"
        path = data.get('photo_path', '')
        if not path.startswith(expected):
            raise HTTPException(404, detail='not_found')
        return bucket().blob(path).download_as_bytes()

    def found_owned(self, report_id, tx=None):
        self.profile(tx, require_active=True)
        event = self.participation_event(tx)
        doc = self.db.collection('found_reports').document(valid_id(report_id)).get(transaction=tx)
        data = doc.to_dict() or {}
        if (data.get('volunteer_uid') or data.get('handed_over_by')) != self.uid or data.get('event_id') != event.id:
            raise HTTPException(404, detail='not_found')
        return doc

    def public_found(self, doc):
        data = doc.to_dict()
        result = {'id': doc.id, 'created_at': data.get('created_at'), 'ai_status': data.get('ai_status', 'unavailable'), 'status': found_lifecycle.found_status(data), 'found_status': found_lifecycle.found_status(data), 'origin': 'volunteer_found', 'event_id': data.get('event_id'),
                  'case_id': data.get('case_id'), 'matched_profile_id': data.get('matched_profile_id'),
                  'ended': data.get('ended', False), 'photo_available': bool(data.get('photo_path')) and not data.get('ended') and not data.get('matched_profile_id')}
        if not data.get('case_id') and data.get('matched_profile_id'):
            person = self.db.collection('users').document(data['guardian_id']).collection('individuals').document(data['individual_id']).get()
            if person.exists:
                result['person'] = self.public_registration(person, contact=True)
            proof = data.get('guardian_verification')
            result['verification'] = {k: v for k, v in proof.items() if k != 'token_hash'} if proof else None
        result.update(handed_over_at=data.get('handed_over_at'), handed_over_by=data.get('handed_over_by'))
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
            result.update(status=state['status'], found_status=found_lifecycle.IDENTIFIED if state['status'] == 'match_confirmed' else state['status'], person=person_data,
                          verification=({k: v for k, v in state['guardian_verification'].items() if k != 'token_hash'} if state.get('guardian_verification') else None), handed_over_at=state.get('handed_over_at'),
                          handed_over_by=state.get('handed_over_by'))
        return result

    def found_list(self):
        self.profile(require_active=True)
        event = self.participation_event()
        docs = self.db.collection('found_reports').where(filter=FieldFilter('volunteer_uid', '==', self.uid)).stream()
        result = []
        for doc in docs:
            data = doc.to_dict()
            if data.get('event_id') != event.id or data.get('ended') or found_lifecycle.found_status(data) == found_lifecycle.REUNITED:
                continue
            case_id = data.get('case_id')
            if case_id and not self.visible(self.cases.document(case_id).get().to_dict() or {}):
                # Guardian closure/retention must not make the entire Volunteer feed fail.
                continue
            result.append(self.public_found(doc))
        return sorted(result, key=lambda d: str(d['created_at']), reverse=True)

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
            event = self.participation_event(tx)
            if ref.get(transaction=tx).exists:
                return False
            tx.set(ref, {'volunteer_uid': self.uid, 'event_id': event.id, 'photo_path': path,
                'created_at': firestore.SERVER_TIMESTAMP, 'updated_at': firestore.SERVER_TIMESTAMP,
                'origin': 'volunteer_found', 'status': found_lifecycle.IDENTIFYING, 'ai_status': 'unavailable', 'matched_profile_id': None, 'case_id': None})
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
        if data.get('ended') or data.get('matched_profile_id'):
            raise HTTPException(404, detail='not_found')
        path = data.get('photo_path', '')
        if not path.startswith(f'found/{self.uid}/{report_id}/'):
            raise HTTPException(404, detail='not_found')
        image = bucket().blob(path).download_as_bytes()
        current = self.found_owned(report_id).to_dict()
        if current.get('ended') or current.get('matched_profile_id'):
            raise HTTPException(404, detail='not_found')
        return image

    def delete_found_photo(self, report_id):
        # State is recorded first, so concurrent readers cannot serve the photo.
        # A failed Storage delete returns an error; retry repeats this idempotent step.
        doc = self.found_owned(report_id)
        path = doc.to_dict().get('photo_path')
        if not path:
            return
        try:
            bucket().blob(path).delete()
        except NotFound:
            pass
        except Exception:
            # Reuse the existing durable cleanup queue if the caller cannot retry.
            self.db.collection('photo_cleanup').document(hashlib.sha256(path.encode()).hexdigest()).set({
                'path': path, 'created_at': firestore.SERVER_TIMESTAMP})
            raise HTTPException(503, detail='photo_deletion_pending') from None
        doc.reference.update({'photo_path': firestore.DELETE_FIELD})

    def end_identification(self, report_id):
        @firestore.transactional
        def end(tx):
            doc = self.found_owned(report_id, tx)
            if doc.to_dict().get('matched_profile_id') or found_lifecycle.found_status(doc.to_dict()) != found_lifecycle.IDENTIFYING:
                raise HTTPException(409, detail='match_already_confirmed')
            if not doc.to_dict().get('ended'):
                tx.update(doc.reference, {'ended': True, 'ended_at': firestore.SERVER_TIMESTAMP})
        end(self.db.transaction())
        self.delete_found_photo(report_id)
        return self.public_found(self.found_owned(report_id))

    def candidates(self, report_id):
        data = self.found_owned(report_id).to_dict()
        if data.get('ended') or found_lifecycle.found_status(data) != found_lifecycle.IDENTIFYING:
            raise HTTPException(409, detail='identification_ended')
        if not data.get('photo_path'):
            raise HTTPException(409, detail='capture_required')
        # Explicit contract for the future model worker; zero fabricated candidates.
        return {'state': 'unavailable', 'candidates': []}

    def submit_manual(self, value):
        self.profile(require_active=True)
        event = self.participation_event()
        report_id = 'FR-' + hashlib.sha256((self.uid + ':manual:' + value.request_id).encode()).hexdigest()[:40]
        seed = {'volunteer_uid': self.uid, 'event_id': event.id,
                'created_at': firestore.SERVER_TIMESTAMP, 'updated_at': firestore.SERVER_TIMESTAMP,
                'origin': 'volunteer_found', 'identification_method': 'manual',
                'status': found_lifecycle.IDENTIFYING, 'ai_status': 'not_requested', 'case_id': None}
        return self.confirm(report_id, value.profile_id, manual_seed=seed)

    def confirm(self, report_id, profile_id, manual_seed=None):
        found = (self.db.collection('found_reports').document(report_id).get()
                 if manual_seed else self.found_owned(report_id))
        if manual_seed and found.exists:
            found = self.found_owned(report_id)

        if (found.to_dict() or {}).get('ended') or found_lifecycle.found_status(found.to_dict() or {}) == found_lifecycle.REUNITED:
            raise HTTPException(409, detail='identification_ended')
        if (found.to_dict() or {}).get('matched_profile_id') == profile_id:
            self.delete_found_photo(report_id)
            return self.public_found(found)
        person_ref = self.registration(profile_id).reference
        push = {}
        @firestore.transactional
        def confirm(tx):
            self.profile(tx, require_active=True)
            event = self.participation_event(tx)
            ref_report = self.db.collection('found_reports').document(report_id)
            report = ref_report.get(transaction=tx)
            creating = manual_seed is not None and not report.exists
            if creating:
                rd = {**manual_seed, 'event_id': event.id}
            else:
                report = self.found_owned(report_id, tx)
                rd = report.to_dict()

            if rd.get('ended') or found_lifecycle.found_status(rd) == found_lifecycle.REUNITED:
                raise HTTPException(409, detail='identification_ended')
            person = person_ref.get(transaction=tx)
            pd = person.to_dict() or {}
            if rd.get('matched_profile_id'):
                if rd['matched_profile_id'] == profile_id:
                    return
                raise HTTPException(409, detail='already_matched')
            if pd.get('deleting') or photo_expired(pd, self.db, tx, case_context=not creating) or pd.get('event_id') != rd['event_id']:
                raise HTTPException(409, detail='profile_unavailable')
            case_id = pd.get('active_case_id')
            linked_id = pd.get('active_found_report_id')
            linked = self.db.collection('found_reports').document(linked_id).get(transaction=tx) if linked_id else None
            if linked and linked.exists and not linked.to_dict().get('ended') and found_lifecycle.found_status(linked.to_dict() or {}) in found_lifecycle.ACTIVE and linked.id != report_id:
                # This registration is already inside an active standalone
                # reunification. Confirming it again from Manual Review is
                # NOT a new identification: if that report is this
                # Volunteer's own, resume it (no duplicate report, no state
                # change) -- the app continues at whatever stage it reached.
                # A camera report of this Volunteer, or another Volunteer's
                # attempt, is refused with a distinct reason instead.
                mine = (linked.to_dict() or {}).get('volunteer_uid') == self.uid
                if creating and mine:
                    return {'resume': linked.id}
                raise HTTPException(409, detail='resume_existing_report' if mine else 'already_matched')
            identity = {'matched_profile_id': profile_id, 'guardian_id': pd['guardian_id'],
                        'individual_id': person.id, 'individual_path': person.reference.path,
                        'confirmed_by': self.uid, 'status': found_lifecycle.IDENTIFIED,
                        'updated_at': firestore.SERVER_TIMESTAMP}
            if not case_id:
                if creating:
                    tx.set(report.reference, rd)
                tx.update(person.reference, {'active_found_report_id': report_id})
                # Standalone only: the short Guardian-readable fallback code,
                # fixed for this report's whole active life.
                tx.update(report.reference, {**identity, 'verification_code': rd.get('verification_code') or found_lifecycle.new_verification_code()})
                return
            ref = self.cases.document(case_id)
            old = ref.get(transaction=tx)
            cd = old.to_dict() or {}
            if case_id and (cd.get('status') not in STAGES[:2] or cd.get('guardian_id') != pd['guardian_id'] or cd.get('individual_id') != person.id or cd.get('event_id') != rd['event_id']):
                raise HTTPException(409, detail='case_not_joinable')
            now = firestore.SERVER_TIMESTAMP
            if creating:
                tx.set(report.reference, rd)
            tx.update(person.reference, {'active_found_report_id': report_id})
            tx.update(ref, {'status': 'match_confirmed', 'confirmed_by': self.uid,
                'found_report_id': report_id, 'updated_at': now, 'stage_timestamps.match_confirmed': now})
            tx.update(report.reference, {**identity, 'case_id': ref.id, 'updated_at': now, 'matched_snapshot': {k: pd.get(k) for k in ('full_name', 'age', 'gender', 'relationship', 'relationship_other')}})
            for uid in set(cd.get('joined_by', [])) - {self.uid}:
                tx.set(self.db.collection('users').document(uid).collection('volunteer_notifications').document(ref.id + '-match_confirmed'),
                    {'case_id': ref.id, 'event_id': rd['event_id'], 'kind': 'status_update', 'status': 'match_confirmed', 'created_at': now, 'read_at': None})
            tx.set(self.db.collection('users').document(pd['guardian_id']).collection('notifications').document(ref.id + '-match_confirmed'),
                {'case_id': ref.id, 'event_id': rd['event_id'], 'kind': 'status_update', 'status': 'match_confirmed', 'created_at': now, 'read_at': None})
            push.update(guardian_id=pd['guardian_id'], case_id=ref.id, event_id=rd['event_id'])
        outcome = confirm(self.db.transaction())
        if isinstance(outcome, dict) and outcome.get('resume'):
            # Nothing was written: hand back the existing report as it stands.
            return self.public_found(self.found_owned(outcome['resume']))
        if push:
            logging.getLogger('uvicorn.error').info('Radd event %s-match_confirmed T2 committed epoch_ms=%d', push['case_id'], time.time()*1000)
        self.delete_found_photo(report_id)
        if push:
            safe_dispatch(self.db, push['case_id'], matched=True)
            # Guardian and Volunteer delivery share the existing Firebase app;
            # their role-specific notification records remain ownership-scoped.
            try:
                notify_guardian(push['guardian_id'], kind='status_update', status='match_confirmed',
                    case_id=push['case_id'], event_id=push['event_id'])
            except Exception:
                pass
        return self.public_found(self.found_owned(report_id))

    def reunification_context(self, report_id, tx=None):
        report = self.found_owned(report_id, tx)
        case_id = report.to_dict().get('case_id')
        if not case_id:
            data = report.to_dict()
            if data.get('status') == found_lifecycle.REUNITED and data.get('handed_over_by') == self.uid:
                return report
            if not data.get('matched_profile_id') or data.get('confirmed_by') != self.uid:
                raise HTTPException(409, detail='match_required')
            return report
        case = self.accessible(case_id, tx)
        if case.to_dict().get('confirmed_by') != self.uid or case.to_dict().get('found_report_id') != report_id:
            raise HTTPException(403, detail='confirmer_required')
        return case

    def begin_verification(self, report_id):
        push = {}
        @firestore.transactional
        def begin(tx):
            case = self.reunification_context(report_id, tx)
            cd = case.to_dict()
            if cd['status'] == 'awaiting_guardian_verification':
                return
            if cd['status'] not in ('match_confirmed', found_lifecycle.IDENTIFIED):
                raise HTTPException(409, detail='invalid_transition')
            now = firestore.SERVER_TIMESTAMP
            tx.update(case.reference, {'status': 'awaiting_guardian_verification', 'updated_at': now,
                'stage_timestamps.awaiting_guardian_verification': now})
            if case.reference.path.startswith('found_reports/'):
                return
            tx.update(self.db.collection('found_reports').document(report_id), {'status': found_lifecycle.VERIFYING, 'updated_at': now})
            # The Guardian must know to open their QR now: same notification
            # record shape as every other Guardian status update.
            tx.set(self.db.collection('users').document(cd['guardian_id']).collection('notifications').document(case.id + '-awaiting_guardian_verification'),
                {'case_id': case.id, 'event_id': cd['event_id'], 'kind': 'status_update', 'status': 'awaiting_guardian_verification', 'created_at': now, 'read_at': None})
            push.update(guardian_id=cd['guardian_id'], case_id=case.id, event_id=cd['event_id'])
        begin(self.db.transaction())
        if push:
            logging.getLogger('uvicorn.error').info('Radd event %s-awaiting_guardian_verification T2 committed epoch_ms=%d', push['case_id'], time.time()*1000)
            try:
                notify_guardian(push['guardian_id'], kind='status_update', status='awaiting_guardian_verification',
                    case_id=push['case_id'], event_id=push['event_id'])
            except Exception:
                pass
        return self.public_found(self.found_owned(report_id))

    def verify_guardian_identifier(self, report_id, case_id):
        # Compare the identifier from the authenticated Guardian's account with
        # this authorized context: a real Missing Case or standalone Found Report.
        # The distinct method/context receipt is required by handover.
        @firestore.transactional
        def verify(tx):
            case = self.reunification_context(report_id, tx)
            cd = case.to_dict()
            if cd['status'] != 'awaiting_guardian_verification':
                raise HTTPException(409, detail='invalid_transition')
            # Missing Case or standalone Found Report alike: the 6-digit code
            # stored on THIS workflow's record only -- never the RD-/FR-
            # document id, never a lookup across other cases or reports. The
            # context (this Volunteer's current report) chooses the record;
            # the code never chooses the context.
            expected = str(cd.get('verification_code') or '')
            presented_code = found_lifecycle.normalize_code(case_id)
            matched = bool(expected) and secrets.compare_digest(presented_code, expected)
            # Safe diagnostic (development log): which record was compared,
            # its stage, whether it holds a code and the SHAPE of the typed
            # value -- never the code, the id beyond a prefix, or any PII.
            logging.getLogger('uvicorn.error').info(
                'Radd verify-identifier context=%s record=%s… status=%s stored_code=%s presented_len=%d presented_digits=%s matched=%s',
                'found_report' if case.reference.path.startswith('found_reports/') else 'missing_case', case.id[:9], cd.get('status'),
                'len=%d' % len(expected) if expected else 'absent', len(presented_code), presented_code.isdigit(), matched)
            if not matched:
                tx.update(case.reference, {'guardian_verification': None})
                return False
            receipt = cd.get('guardian_verification') or {}
            if receipt.get('volunteer_uid') == self.uid and receipt.get('method') in ('case_identifier', 'found_identifier') and found_lifecycle.proof_context(receipt) == case.id:
                return True
            now = firestore.SERVER_TIMESTAMP
            tx.update(case.reference, {'guardian_verification': {'method': 'found_identifier' if case.reference.path.startswith('found_reports/') else 'case_identifier', 'volunteer_uid': self.uid,
                'guardian_id': cd['guardian_id'], **found_lifecycle.context_fields(case), 'verified_at': now}, 'updated_at': now})
            return True
        return {'verified': verify(self.db.transaction()), 'report': self.public_found(self.found_owned(report_id))}

    def verify_guardian(self, report_id, payload):
        # The QR is Guardian-account-level, not per-case: the payload names WHICH
        # guardian, and this Volunteer's authorized reunification context supplies
        # the case or Found Report association. A scan only proves "this account", so the association
        # to the case is re-checked here (case.guardian_id must equal the scanned
        # guardian_id) before the challenge is even looked up.
        @firestore.transactional
        def verify(tx):
            case = self.reunification_context(report_id, tx)
            cd = case.to_dict()
            if cd['status'] != 'awaiting_guardian_verification':
                raise HTTPException(409, detail='invalid_transition')
            prefix = 'radd:guardian-verification:v1:'
            rest = payload[len(prefix):] if payload.startswith(prefix) else ''
            subject, _, nonce = rest.partition(':')
            associated = bool(subject and '/' not in subject and subject in (cd['guardian_id'], case.id))
            digest = hashlib.sha256(nonce.encode()).hexdigest() if nonce else ''
            receipt = cd.get('guardian_verification') or {}
            if associated and receipt.get('volunteer_uid') == self.uid and found_lifecycle.proof_context(receipt) == case.id and receipt.get('guardian_id') == cd['guardian_id'] and receipt.get('token_hash') == digest and nonce:
                return True
            challenge = None
            if associated and nonce:
                owner = case.reference if subject == case.id else self.db.collection('users').document(cd['guardian_id'])
                challenge = owner.collection('verification').document('current').get(transaction=tx)
            data = (challenge.to_dict() or {}) if challenge else {}
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
                'guardian_id': cd['guardian_id'], **found_lifecycle.context_fields(case), 'verified_at': now, 'token_hash': digest}, 'updated_at': now})
            return True
        return {'verified': verify(self.db.transaction()), 'report': self.public_found(self.found_owned(report_id))}

    def handover_found(self, report_id):
        report = self.found_owned(report_id).to_dict()
        if report.get('matched_profile_id'):
            self.delete_found_photo(report_id)
        push = {}
        @firestore.transactional
        def handover(tx):
            case = self.reunification_context(report_id, tx)
            cd = case.to_dict()
            if cd['status'] == found_lifecycle.REUNITED and cd.get('handed_over_by') == self.uid:
                return
            person = self.db.collection('users').document(cd['guardian_id']).collection('individuals').document(cd['individual_id']).get(transaction=tx)
            proof = cd.get('guardian_verification') or {}
            if cd['status'] == 'reunited' and cd.get('handed_over_by') == self.uid:
                return
            # Either verification method authorizes handover; the recorded
            # method itself is retained on the case for the handover record.
            if cd['status'] != 'awaiting_guardian_verification' or proof.get('method') not in ('qr', 'case_identifier', 'found_identifier') or proof.get('volunteer_uid') != self.uid or found_lifecycle.proof_context(proof) != case.id or proof.get('guardian_id') != cd['guardian_id']:
                raise HTTPException(409, detail='guardian_verification_required')
            now = firestore.SERVER_TIMESTAMP
            if case.reference.path.startswith('found_reports/'):
                completed = {**cd, 'status': found_lifecycle.REUNITED, 'handed_over_at': now, 'handed_over_by': self.uid}
                tx.set(case.reference, found_lifecycle.minimal_completed(completed))
                if person.exists and person.to_dict().get('active_found_report_id') == report_id:
                    tx.update(person.reference, {'active_found_report_id': firestore.DELETE_FIELD})
                return
            tx.update(case.reference, {'status': 'reunited', 'updated_at': now, 'stage_timestamps.reunited': now,
                'handed_over_at': now, 'handed_over_by': self.uid, 'closed_at': now,
                'age_group': cd.get('age_group') or age_group(cd['age']),
                'verification_code': firestore.DELETE_FIELD})
            tx.update(self.db.collection('found_reports').document(report_id), {'status': found_lifecycle.REUNITED, 'handed_over_at': now, 'handed_over_by': self.uid, 'verification_method': proof.get('method'), 'updated_at': now})
            if person.exists and person.to_dict().get('active_case_id') == case.id:
                tx.update(person.reference, {'active_case_id': None, 'active_found_report_id': firestore.DELETE_FIELD, 'updated_at': now})
            tx.set(self.db.collection('users').document(cd['guardian_id']).collection('notifications').document(case.id + '-reunited'),
                {'case_id': case.id, 'event_id': cd['event_id'], 'kind': 'status_update', 'status': 'reunited', 'created_at': now, 'read_at': None})
            push.update(guardian_id=cd['guardian_id'], case_id=case.id, event_id=cd['event_id'])
        handover(self.db.transaction())
        if push:
            logging.getLogger('uvicorn.error').info('Radd event %s-reunited T2 committed epoch_ms=%d', push['case_id'], time.time()*1000)
            safe_dispatch(self.db, push['case_id'])
            try:
                notify_guardian(push['guardian_id'], kind='status_update', status='reunited',
                    case_id=push['case_id'], event_id=push['event_id'])
            except Exception:
                pass
        return self.public_found(self.found_owned(report_id))

    def notifications_list(self):
        self.profile(require_active=True)
        event = self.participation_event()
        collection = self.user.collection('volunteer_notifications')
        existing = {doc.id for doc in collection.stream()}
        # Materialize actual event case notifications lazily, using stable IDs and
        # transactional create-if-absent. No fake records, no Guardian changes.
        for case in self.cases.where(filter=FieldFilter('event_id', '==', event.id)).stream():
            if case.to_dict().get('status') not in STAGES[:2]:
                continue
            ref = collection.document(case.id + '-new')
            # Polling must not open a transaction for every historical alert.
            # Missing alerts still use the authoritative transactional checks.
            if ref.id in existing:
                continue
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
        return sorted([{'id': d.id, **d.to_dict()} for d in collection.stream() if d.to_dict().get('event_id') == event.id],
            key=lambda row: str(row.get('created_at', '')), reverse=True)

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
    def profile_detail(profile_id: str, found_report_id: str | None = None,
                       case_id: str | None = None, s=Depends(service)):
        return s.profile_detail(profile_id, found_report_id, case_id)
    @router.get('/profiles/{profile_id}/photo')
    def profile_photo(profile_id: str, s=Depends(service)):
        return Response(s.registration_photo(profile_id), media_type='image/jpeg', headers={'Cache-Control': 'no-store'})
    @router.get('/found-reports')
    def reports(s=Depends(service)):
        return s.found_list()
    @router.post('/found-reports', status_code=201)
    def submit(value: FoundInput, s=Depends(service)):
        return s.submit_found(value)
    @router.post('/found-reports/manual', status_code=201)
    def submit_manual(value: ManualFoundInput, s=Depends(service)):
        return s.submit_manual(value)
    @router.get('/found-reports/{report_id}')
    def report(report_id: str, s=Depends(service)):
        return s.public_found(s.found_owned(report_id))
    @router.get('/found-reports/{report_id}/photo')
    def found_photo(report_id: str, s=Depends(service)):
        return Response(s.found_photo(report_id), media_type='image/jpeg', headers={'Cache-Control': 'no-store'})
    @router.get('/found-reports/{report_id}/registered-photo')
    def matched_photo(report_id: str, s=Depends(service)):
        case = s.reunification_context(report_id).to_dict()
        if case.get('status') == found_lifecycle.REUNITED:
            raise HTTPException(404, detail='not_found')
        doc = s.db.collection('users').document(case['guardian_id']).collection('individuals').document(case['individual_id']).get()
        return Response(s.registration_bytes(doc, report_id), media_type='image/jpeg', headers={'Cache-Control': 'no-store'})
    @router.get('/found-reports/{report_id}/candidates')
    def candidates(report_id: str, s=Depends(service)):
        return s.candidates(report_id)
    @router.post('/found-reports/{report_id}/end')
    def end_identification(report_id: str, s=Depends(service)):
        return s.end_identification(report_id)
    @router.post('/found-reports/{report_id}/confirm-match')
    def confirm(report_id: str, value: MatchInput, s=Depends(service)):
        return s.confirm(report_id, value.profile_id)
    @router.post('/found-reports/{report_id}/begin-verification')
    def begin(report_id: str, s=Depends(service)):
        return s.begin_verification(report_id)
    @router.post('/found-reports/{report_id}/verify')
    def verify(report_id: str, value: VerifyInput, s=Depends(service)):
        return s.verify_guardian(report_id, value.payload)
    @router.post('/found-reports/{report_id}/verify-identifier')
    def verify_identifier(report_id: str, value: IdentifierVerifyInput, s=Depends(service)):
        return s.verify_guardian_identifier(report_id, value.case_id)
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
