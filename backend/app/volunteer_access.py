"""Shared event authorization and privileged account/assignment operations.

Management operations are internal services, not public endpoints. A future
Admin API must authorize its caller before invoking them; the local ADC CLI is
the current trusted operator boundary.
"""
from fastapi import HTTPException
from firebase_admin import firestore
from .events import active_event
import logging
from firebase_admin import messaging
from .firebase import firebase_app


def signal_access_change(user):
    """Non-sensitive invalidation hint; authorization always comes from API.

    Best-effort foreground acceleration. The client's existing periodic/resume
    recovery remains authoritative if delivery fails or the app is backgrounded.
    """
    try:
        for registration in user.collection('fcm_registrations').stream():
            token = registration.to_dict().get('token')
            if token:
                messaging.send(messaging.Message(token=token,
                    data={'role': 'volunteer', 'kind': 'access_changed'},
                    android=messaging.AndroidConfig(priority='high')),
                    app=firebase_app())
    except Exception as error:
        logging.getLogger('uvicorn.error').warning('Volunteer access hint failed (%s)', type(error).__name__)


def assignment_ref(db, event_id, uid):
    for value in (event_id, uid):
        if not isinstance(value, str) or not value or '/' in value:
            raise ValueError('Invalid event or Volunteer identifier')
    return db.collection('events').document(event_id).collection('volunteers').document(uid)


def event_access(db, uid, tx=None):
    try:
        event = active_event(db, tx)
    except HTTPException as error:
        if error.detail == 'event_unavailable':
            return {'event_id': None, 'assigned': False, 'event_name': None}
        raise
    assigned = assignment_ref(db, event.id, uid).get(transaction=tx).exists
    name = (event.to_dict() or {}).get('name')
    return {'event_id': event.id, 'assigned': assigned,
            'event_name': name if assigned and isinstance(name, str) and name.strip() else None}


def eligible_for_event(db, uid, event_id):
    state = event_access(db, uid)
    return state['assigned'] and state['event_id'] == event_id


def require_event(db, uid, tx=None):
    """Bind each query to the same event whose assignment was checked."""
    try:
        event = active_event(db, tx)
    except HTTPException as error:
        if error.detail == 'event_unavailable':
            raise HTTPException(403, detail='event_access_required') from None
        raise
    if not assignment_ref(db, event.id, uid).get(transaction=tx).exists:
        raise HTTPException(403, detail='event_access_required')
    return event


class VolunteerManagement:
    def __init__(self, db):
        self.db = db

    def change(self, uid, *, actor, operation, event_id=None):
        if not isinstance(actor, str) or not actor.strip():
            raise ValueError('An accountable operator identifier is required')
        if operation not in ('assign', 'remove', 'enable', 'deactivate'):
            raise ValueError('Unsupported operation')
        if not uid or '/' in uid:
            raise ValueError('Invalid Volunteer identifier')
        user = self.db.collection('users').document(uid)
        assignment = assignment_ref(self.db, event_id, uid) if operation in ('assign', 'remove') else None

        @firestore.transactional
        def apply(tx):
            data = user.get(transaction=tx).to_dict() or {}
            if data.get('role') != 'volunteer':
                raise ValueError('An existing Volunteer profile is required; other accounts cannot be changed')
            if assignment is not None:
                event = self.db.collection('events').document(event_id).get(transaction=tx)
                if not event.exists:
                    raise ValueError('Event does not exist')
                if operation == 'assign':
                    tx.set(assignment, {'updated_at': firestore.SERVER_TIMESTAMP, 'updated_by': actor})
                else:
                    tx.delete(assignment)
            else:
                tx.update(user, {'active': operation == 'enable',
                                 'updated_at': firestore.SERVER_TIMESTAMP, 'updated_by': actor})
        apply(self.db.transaction())
        signal_access_change(user)
