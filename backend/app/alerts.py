"""Shared Guardian/Volunteer alert intents.

Guardian case creation persists the general intent in the case transaction.
volunteer_alerts dispatches real FCM and records per-device delivery receipts
under the recipient's notification. No delivery is inferred from an intent.
"""
from firebase_admin import firestore

# Retained for the existing Volunteer profile/display contract.
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
