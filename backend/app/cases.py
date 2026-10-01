"""Ownership-scoped Guardian operations on the shared top-level cases collection."""
import hashlib
import logging
import time
from datetime import datetime, timedelta, timezone
import secrets
from fastapi import HTTPException
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from .case_models import STAGES, TERMINAL_STATUSES, age_group
from .events import active_event
from .service import owned_registration, photo_expired
from .alerts import general_alert
from .push import notify_guardian
from .volunteer_alerts import safe_dispatch
from .found_reports import new_verification_code

def public_case(doc):
    data = doc.to_dict()
    # `verification_code` is the 6-digit value the Guardian reads to the
    # Volunteer when the QR cannot be scanned (never the RD-… document id,
    # which stays the internal identity). Gone once the case is terminal.
    return {"id": doc.id, **{k: data.get(k) for k in (
        "individual_id", "individual_name", "age", "age_group", "event_id", "status",
        "created_at", "updated_at", "closed_at", "stage_timestamps", "guided_report")},
        "verification_code": None if data.get("status") in TERMINAL_STATUSES else data.get("verification_code")}

def active_case_codes(db, event_id, tx=None):
    """Codes held by the event's non-terminal cases: the collision scope."""
    codes = set()
    for d in db.collection("cases").where(filter=FieldFilter("event_id", "==", event_id)).stream(transaction=tx):
        data = d.to_dict() or {}
        if data.get("status") not in TERMINAL_STATUSES and data.get("verification_code"):
            codes.add(str(data["verification_code"]))
    return codes

def unique_case_code(db, event_id, tx=None, attempts=25):
    """Secure 6-digit code not currently used by another active case of the
    event. Never a document id: RD-… remains the case's identity."""
    taken = active_case_codes(db, event_id, tx)
    for _ in range(attempts):
        code = new_verification_code()
        if code not in taken:
            return code
    raise HTTPException(503, detail="verification_code_unavailable")

def validate_transition(current, target):
    if current not in STAGES or target not in STAGES or STAGES.index(target) != STAGES.index(current) + 1:
        raise HTTPException(409, detail="invalid_transition")

class CaseService:
    def __init__(self, guardian):
        guardian.profile()
        self.guardian = guardian
        self.db, self.uid = guardian.db, guardian.uid
        self.cases = self.db.collection("cases")
        self.notifications = guardian.user.collection("notifications")

    def owned(self, case_id, tx=None):
        if not case_id or "/" in case_id:
            raise HTTPException(404)
        doc = self.cases.document(case_id).get(transaction=tx)
        owned_registration(doc.to_dict(), self.uid)
        return doc

    def list(self):
        docs = self.cases.where(filter=FieldFilter("guardian_id", "==", self.uid)).stream()
        return sorted([public_case(self.ensure_code(d)) for d in docs], key=lambda d: str(d["created_at"]), reverse=True)

    def get(self, case_id):
        return public_case(self.ensure_code(self.owned(case_id)))

    def ensure_code(self, doc):
        """A case created before short codes existed receives one, once, the
        first time its Guardian reads it: same document, same RD-… id, same
        status. Terminal cases never receive one."""
        data = doc.to_dict() or {}
        if data.get("verification_code") or data.get("status") in TERMINAL_STATUSES:
            return doc
        @firestore.transactional
        def assign(tx):
            current = doc.reference.get(transaction=tx).to_dict() or {}
            if current.get("verification_code") or current.get("status") in TERMINAL_STATUSES:
                return
            tx.update(doc.reference, {"verification_code": unique_case_code(self.db, current["event_id"], tx)})
        assign(self.db.transaction())
        return self.owned(doc.id)

    def create(self, value):
        from .found_reports import identified_report, VERIFYING
        person = self.guardian.user.collection("individuals").document(value.individual_id)
        ref = self.cases.document("RD-" + secrets.token_hex(6).upper())
        created_new = False
        @firestore.transactional
        def create(tx):
            person_doc = person.get(transaction=tx)
            data = owned_registration(person_doc.to_dict(), self.uid)
            event_doc = active_event(self.db, tx)
            event_id = event_doc.id
            collision = ref.get(transaction=tx)
            active_id = data.get("active_case_id")
            active = self.owned(active_id, tx) if active_id else None
            if not event_doc.exists or event_doc.to_dict().get("active") is not True:
                raise HTTPException(503, detail="event_unavailable")
            if data.get("deleting"):
                raise HTTPException(409, detail="deletion_in_progress")
            if active:
                return active.id  # Idempotent retry after a lost response.
            # New reports require an available reference photo under the
            # established registration period, enforced on the server.
            if not data.get("photo_path") or photo_expired(data, self.db, tx):
                raise HTTPException(409, detail="photo_expired")
            if data.get("event_id") != event_id:
                raise HTTPException(409, detail="registration_unavailable")
            found = identified_report(self.db, data, tx)
            if collision.exists:
                raise HTTPException(409, detail="identifier_conflict")
            nonlocal created_new
            created_new = True
            now = firestore.SERVER_TIMESTAMP
            linked = found.to_dict() if found else {}
            state = (VERIFYING if linked.get('status') == VERIFYING else 'match_confirmed') if found else STAGES[0]
            tx.set(ref, {"guardian_id": self.uid, "individual_id": value.individual_id,
                "individual_path": person.path, "individual_name": data["full_name"],
                "age": data["age"], "age_group": age_group(data["age"]),
                "event_id": event_id, "status": state,
                # Guardian-readable fallback for this active workflow only;
                # never stored on the individual, never the case id.
                "verification_code": unique_case_code(self.db, event_id, tx),
                **({"found_report_id": found.id, "confirmed_by": linked["confirmed_by"], "guardian_verification": ({**linked["guardian_verification"], "case_id": ref.id, "context_id": ref.id, "context_type": "missing_case"} if linked.get("guardian_verification") else None)} if found else {}),
                "created_at": now, "updated_at": now, "closed_at": None,
                "stage_timestamps": {state: now}, "guided_report": None})
            tx.update(person, {"active_case_id": ref.id})
            if found:
                tx.update(found.reference, {'case_id': ref.id, 'updated_at': now})
                tx.set(self.notifications.document(ref.id + '-' + state), {
                    'event_id': event_id, 'case_id': ref.id, 'kind': 'status_update',
                    'status': state, 'created_at': now, 'read_at': None})
                return ref.id
            # The initial general Volunteer alert happens as part of this same
            # successful case-creation transaction -- never delayed by the
            # (separate, subsequent) Guided Assistant step.
            general_alert(self.db, tx, case_id=ref.id, event_id=event_id, status=STAGES[0])
            tx.set(self.notifications.document(ref.id + "-report_received"), {
                "event_id": event_id, "case_id": ref.id, "kind": "case_created", "status": STAGES[0],
                "created_at": now, "read_at": None})
            return ref.id
        result = public_case(self.owned(create(self.db.transaction())))
        if created_new:
            logging.getLogger("uvicorn.error").info("Radd event %s-new T2 committed epoch_ms=%d", result["id"], time.time()*1000)
            safe_dispatch(self.db, result['id'])
            # Push is an ADDITIONAL channel alongside the notification doc
            # already written above -- never a replacement for it, and never
            # allowed to affect this already-committed business operation.
            try:
                notify_guardian(self.uid, kind="case_created" if result["status"] == STAGES[0] else "status_update", status=result["status"],
                    case_id=result["id"], event_id=result["event_id"])
            except Exception:
                pass
        return result

    def save_report(self, case_id, value):
        @firestore.transactional
        def save(tx):
            doc = self.owned(case_id, tx)
            data = doc.to_dict()
            if data["status"] in TERMINAL_STATUSES:
                raise HTTPException(409, detail="case_closed")
            # Guided Assistant answers become read-only Case Details once submitted;
            # this is not a permanent editable chat session.
            if (data.get("guided_report") or {}).get("completed"):
                raise HTTPException(409, detail="report_already_submitted")
            tx.update(doc.reference, {"guided_report": value.model_dump(),
                "updated_at": firestore.SERVER_TIMESTAMP})
        save(self.db.transaction())
        safe_dispatch(self.db, case_id)
        return public_case(self.owned(case_id))

    def _terminate(self, case_id, outcome):
        # Shared by cancel() and resolve(): a Guardian-initiated terminal outcome,
        # reachable from any still-active case (never sequential, never via
        # validate_transition). Clears active_case_id so normal profile
        # management (edit/delete) can resume on the individual.
        @firestore.transactional
        def terminate(tx):
            doc = self.owned(case_id, tx)
            data = doc.to_dict()
            if data["status"] in TERMINAL_STATUSES:
                raise HTTPException(409, detail="case_closed")
            person = self.guardian.user.collection("individuals").document(data["individual_id"])
            now = firestore.SERVER_TIMESTAMP
            tx.update(doc.reference, {"status": outcome, "updated_at": now, "closed_at": now,
                                      "verification_code": firestore.DELETE_FIELD})
            tx.update(person, {"active_case_id": None, "active_found_report_id": firestore.DELETE_FIELD})
            if data.get('found_report_id'):
                tx.update(self.db.collection('found_reports').document(data['found_report_id']),
                          {'ended': True, 'ended_at': now, 'updated_at': now})
            tx.set(self.notifications.document(case_id + "-" + outcome), {
                "event_id": data["event_id"], "case_id": case_id, "kind": "status_changed",
                "status": outcome, "created_at": firestore.SERVER_TIMESTAMP, "read_at": None})
        terminate(self.db.transaction())
        logging.getLogger("uvicorn.error").info("Radd event %s-%s T2 committed epoch_ms=%d", case_id, outcome, time.time()*1000)
        safe_dispatch(self.db, case_id)
        result = public_case(self.owned(case_id))
        try:
            notify_guardian(self.uid, kind="status_changed", status=outcome,
                case_id=case_id, event_id=result["event_id"])
        except Exception:
            pass
        return result

    def cancel(self, case_id):
        """Guardian reports a mistaken case; never confuse with a Volunteer-confirmed reunification."""
        return self._terminate(case_id, "cancelled")

    def resolve(self, case_id):
        """Guardian independently found the individual; never confuse with Reunited."""
        return self._terminate(case_id, "resolved")

    def list_notifications(self):
        return sorted([{"id": d.id, **d.to_dict()} for d in self.notifications.stream()],
            key=lambda d: str(d["created_at"]), reverse=True)

    def mark_read(self, notification_id):
        if not notification_id or "/" in notification_id:
            raise HTTPException(404)
        ref = self.notifications.document(notification_id)
        @firestore.transactional
        def mark(tx):
            doc = ref.get(transaction=tx)
            if not doc.exists:
                raise HTTPException(404)
            if doc.to_dict().get("read_at") is None:
                tx.update(ref, {"read_at": firestore.SERVER_TIMESTAMP})
        mark(self.db.transaction())

    def verification(self, case_id):
        """Compatibility issuer for the existing Volunteer case-specific QR flow."""
        nonce = secrets.token_urlsafe(32)
        digest = hashlib.sha256(nonce.encode()).hexdigest()
        expires = datetime.now(timezone.utc) + timedelta(minutes=5)
        @firestore.transactional
        def issue(tx):
            doc = self.owned(case_id, tx)
            if doc.to_dict()['status'] != 'awaiting_guardian_verification':
                raise HTTPException(409, detail='verification_not_ready')
            tx.set(doc.reference.collection('verification').document('current'), {
                'token_hash': digest, 'guardian_id': self.uid, 'event_id': doc.to_dict()['event_id'],
                'expires_at': expires, 'consumed_at': None})
        issue(self.db.transaction())
        return {'case_id': case_id, 'payload': 'radd:guardian-verification:v1:' + case_id + ':' + nonce, 'expires_at': expires}

# No Guardian status mutation endpoint. Volunteer/Admin services must call a
# transactional transition with role/event authorization and verification proof.
# validate_transition is the shared ordered-progression guard.
#
# Guardian-side contract for the Admin closure "Referred to Authority"
# (status ADMIN_TERMINAL_OUTCOME, implemented by the Admin module): it is
# terminal exactly like cancel()/resolve() above -- set `status`, `updated_at`
# and `closed_at`; clear the individual's `active_case_id` (and
# `active_found_report_id`); end a linked found report; write the Guardian's
# notification record `users/{uid}/notifications/{case_id}-referred_to_authority`
# (kind `status_changed`) and call push.notify_guardian with the same values.
# Guardian screens, colours, labels (both languages), push validation and the
# retention scrub already understand this status; nothing on the Guardian
# side needs to change when that transition is implemented.
# Guardian verification is account-level (GuardianService.account_verification),
# not per-case: the case context comes from the Volunteer's own current case
# (VolunteerWorkflow.verify_guardian). A case identifier alone is not proof of identity.
