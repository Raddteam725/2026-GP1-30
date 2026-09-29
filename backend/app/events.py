"""The authoritative event record: one Active event per deployment.

`events/{eventId}` is the single source of truth every actor reads:
Guardian registration and reporting (GET /v1/event, /v1/registration-periods),
Volunteer participation, and -- when its module is implemented -- the Admin
Portal that manages it. Fields (Sprint-0 event configuration):

    name, location, starts_at, ends_at, operating_hours, registration_periods
    active (bool)      -- exactly one event may be True; the query key
    activated_at, closed_at, created_at, updated_at, updated_by, environment

Status is derived, never stored twice: `active` -> "active"; `closed_at`
set -> "closed"; otherwise "upcoming". Event management (create, configure,
activate, close) belongs to the Admin module; this module only reads the
record and provides the controlled development bootstrap. Bootstrap is
explicit setup, never an API side effect.
"""
import re
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

EVENT_STATUSES = ("upcoming", "active", "closed")
_TIME = re.compile(r"^([01][0-9]|2[0-3]):[0-5][0-9]$")
SUMMARY_FIELDS = ("name", "location", "starts_at", "ends_at", "operating_hours",
                  "registration_periods", "environment", "activated_at", "closed_at",
                  "created_at", "updated_at")

def event_status(data):
    if data.get("active") is True:
        return "active"
    if data.get("closed_at") is not None:
        return "closed"
    return "upcoming"

def event_summary(doc):
    """Non-sensitive event description shared by Guardian, Volunteer and Admin."""
    data = doc.to_dict() or {}
    return {"id": doc.id, "status": event_status(data), **{k: data.get(k) for k in SUMMARY_FIELDS}}

def active_event(db, transaction=None):
    docs = list(db.collection("events").where(filter=FieldFilter("active", "==", True)).limit(2).stream(transaction=transaction))
    if len(docs) > 1:
        raise HTTPException(503, detail="multiple_active_events")
    if not docs:
        raise HTTPException(503, detail="event_unavailable")
    return docs[0]

def validated(current, proposed):
    """Full event configuration check: details plus the retention contract
    (registration_retention.validate_configuration). Used by the bootstrap
    below and reusable by the Admin module's management operations."""
    from .registration_retention import validate_configuration
    name = proposed.get("name")
    if not isinstance(name, str) or not name.strip() or len(name) > 120:
        raise ValueError("An event name (1-120 characters) is required")
    location = proposed.get("location")
    if location is not None and (not isinstance(location, str) or len(location) > 200):
        raise ValueError("Location must be text of at most 200 characters")
    hours = proposed.get("operating_hours")
    if hours is not None:
        if (not isinstance(hours, dict) or set(hours) != {"opens", "closes"}
                or not all(isinstance(hours[k], str) and _TIME.match(hours[k]) for k in ("opens", "closes"))):
            raise ValueError("operating_hours must be {opens: HH:MM, closes: HH:MM}")
    validate_configuration(current, proposed)
    return {k: proposed.get(k) for k in ("name", "location", "starts_at", "ends_at", "operating_hours", "registration_periods")}

def development_configuration(now=None):
    """The controlled bootstrap record's configuration -- the REAL event schema
    with development-only values, so nothing in Guardian logic ever depends on
    a fake event. An Admin-managed event replaces it by data alone."""
    now = now or datetime.now(timezone.utc)
    return {"name": "Radd Sprint 0 Development", "location": "Development environment",
            "starts_at": now - timedelta(hours=1), "ends_at": now + timedelta(days=30),
            "operating_hours": {"opens": "00:00", "closes": "23:59"},
            "registration_periods": [{"id": "24h", "duration_hours": 24},
                                     {"id": "72h", "duration_hours": 72},
                                     {"id": "7d", "duration_hours": 168}]}

def bootstrap_development_event(db):
    """Creates ONE fully configured development event if none is Active.

    Idempotent: an existing Active event (development or Admin-managed) is
    left exactly as it is -- this never edits or replaces event data.
    """
    lock = db.collection("configuration").document("event_bootstrap")
    ref = db.collection("events").document()
    config = validated({}, development_configuration())
    @firestore.transactional
    def bootstrap(tx):
        lock.get(transaction=tx)
        docs = list(db.collection("events").where(filter=FieldFilter("active", "==", True)).limit(2).stream(transaction=tx))
        if len(docs) > 1:
            raise HTTPException(503, detail="multiple_active_events")
        if docs:
            return docs[0].id
        now = firestore.SERVER_TIMESTAMP
        tx.set(ref, {**config, "active": True, "environment": "development", "activated_at": now,
                     "created_at": now, "updated_at": now, "updated_by": "development-bootstrap"})
        tx.set(lock, {"event_id": ref.id, "updated_at": now})
        return ref.id
    return bootstrap(db.transaction())
