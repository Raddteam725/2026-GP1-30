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

def public_case(doc):
    data = doc.to_dict()
    return {"id": doc.id, **{k: data.get(k) for k in (
        "individual_id", "individual_name", "age", "age_group", "event_id", "status",
        "created_at", "updated_at", "closed_at", "stage_timestamps", "guided_report")}}

def validate_transition(current, target):
    if current not in STAGES or target not in STAGES or STAGES.index(target) != STAGES.index(current) + 1:
        raise HTTPException(409, detail="invalid_transition")

def _timing(op, case_id, started):
    # T2/T3 of the integration timeline: the authoritative commit (which in
    # this service always includes the durable notification records) is
    # complete. Identifiers and durations only.
    logging.getLogger("radd.timing").info("Radd timing: T3 committed op=%s case=%s commit_ms=%d",
                                          op, case_id, int((time.monotonic() - started) * 1000))

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
        return sorted([public_case(d) for d in docs], key=lambda d: str(d["created_at"]), reverse=True)

    def create(self, value):
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
            # A report only becomes possible with a current photo -- this is
            # the authoritative, server-side gate; the Flutter UI's own
            # "needs a new photo" prompt is a convenience, not the enforcement.
            if not data.get("photo_path") or photo_expired(data):
                raise HTTPException(409, detail="photo_expired")
            if collision.exists:
                raise HTTPException(409, detail="identifier_conflict")
            nonlocal created_new
            created_new = True
            now = firestore.SERVER_TIMESTAMP
            tx.set(ref, {"guardian_id": self.uid, "individual_id": value.individual_id,
                "individual_path": person.path, "individual_name": data["full_name"],
                "age": data["age"], "age_group": age_group(data["age"]),
                "event_id": event_id, "status": STAGES[0],
                "created_at": now, "updated_at": now, "closed_at": None,
                "stage_timestamps": {STAGES[0]: now}, "guided_report": None})
            tx.update(person, {"active_case_id": ref.id})
            # The initial general Volunteer alert happens as part of this same
            # successful case-creation transaction -- never delayed by the
            # (separate, subsequent) Guided Assistant step.
            general_alert(self.db, tx, case_id=ref.id, event_id=event_id, status=STAGES[0])
            tx.set(self.notifications.document(ref.id + "-report_received"), {
                "event_id": event_id, "case_id": ref.id, "kind": "case_created", "status": STAGES[0],
                "created_at": now, "read_at": None})
            return ref.id
        started = time.monotonic()
        result = public_case(self.owned(create(self.db.transaction())))
        if created_new:
            _timing("create", result["id"], started)
            # Immediate delivery, still inside this request, straight after
            # the commit: the Volunteer alert (durable record + push) and the
            # Guardian's own push. Both are ADDITIONAL channels alongside the
            # records already written above -- never a replacement for them,
            # never allowed to affect this already-committed operation, and
            # never something the response waits on beyond the bounded FCM
            # attempt (see app.delivery).
            safe_dispatch(self.db, result['id'])
            try:
                notify_guardian(self.uid, kind="case_created", status=result["status"],
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
        started = time.monotonic()
        @firestore.transactional
        def terminate(tx):
            doc = self.owned(case_id, tx)
            data = doc.to_dict()
            if data["status"] in TERMINAL_STATUSES:
                raise HTTPException(409, detail="case_closed")
            person = self.guardian.user.collection("individuals").document(data["individual_id"])
            now = firestore.SERVER_TIMESTAMP
            tx.update(doc.reference, {"status": outcome, "updated_at": now, "closed_at": now})
            tx.update(person, {"active_case_id": None})
            tx.set(self.notifications.document(case_id + "-" + outcome), {
                "event_id": data["event_id"], "case_id": case_id, "kind": "status_changed",
                "status": outcome, "created_at": firestore.SERVER_TIMESTAMP, "read_at": None})
        terminate(self.db.transaction())
        _timing(outcome, case_id, started)
        result = public_case(self.owned(case_id))
        # The Volunteers who were alerted to this case are told it is closed
        # -- durable `volunteer_notifications/{case}-{outcome}` records plus
        # the immediate push (see volunteer_alerts.dispatch) -- so it never
        # silently disappears from their active list. Then the Guardian's
        # own push. Neither can affect the committed outcome above.
        safe_dispatch(self.db, case_id)
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
# Guardian verification is account-level (GuardianService.account_verification),
# not per-case: the case context comes from the Volunteer's own current case
# (VolunteerWorkflow.verify_guardian). A case identifier alone is not proof of identity.
