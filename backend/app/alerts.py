"""Shared Guardian/Volunteer alert intents.

Guardian case creation persists the general intent in the case transaction.
volunteer_alerts dispatches real FCM and records per-device delivery receipts
under the recipient's notification. No delivery is inferred from an intent.
"""
from firebase_admin import firestore

# Nearby is defined centrally so every consumer (the proximity worker,
# tests, ops tooling) agrees on the same number. Subject to tuning during
# system testing -- change this one constant, not call sites.
PROXIMITY_RADIUS_METERS = 500

def general_alert(db, tx, *, case_id, event_id, status):
    """Persist the initial general alert intent for all active Volunteers.

    Called once, inside the same transaction as case creation, immediately
    after the case document is written and before anything else -- the
    initial general alert must never be delayed by the Guided Assistant.
    This broadcast-scoped intent is fanned out through volunteer_alerts using
    authenticated device registrations; delivery receipts live with each
    recipient notification.
    """
    ref = db.collection("alerts").document()
    tx.set(ref, {
        "case_id": case_id, "event_id": event_id, "kind": "general",
        "status": status, "recipient_volunteer_id": None,
        "proximity_eligible": None, "distance_meters": None,
        "delivered": False, "created_at": firestore.SERVER_TIMESTAMP,
    })
    return ref.id

def priority_alert(db, tx, *, case_id, event_id, status, volunteer_id, distance_meters):
    """Persist a priority alert intent for one Volunteer within PROXIMITY_RADIUS_METERS.

    The delivery service uses deterministic per-case/recipient intent IDs
    so retries do not create duplicate priority intents. Kept here, alongside the general
    alert it mirrors, as the documented shape the proximity worker
    (comparing a case's guided-report last-seen coordinates against
    available Volunteer locations) should write to -- so Guardian, Volunteer
    and Admin code all target one canonical `alerts` shape from day one.
    """
    if distance_meters > PROXIMITY_RADIUS_METERS:
        raise ValueError("distance_meters exceeds PROXIMITY_RADIUS_METERS")
    ref = db.collection("alerts").document()
    tx.set(ref, {
        "case_id": case_id, "event_id": event_id, "kind": "priority",
        "status": status, "recipient_volunteer_id": volunteer_id,
        "proximity_eligible": True, "distance_meters": distance_meters,
        "delivered": False, "created_at": firestore.SERVER_TIMESTAMP,
    })
    return ref.id
