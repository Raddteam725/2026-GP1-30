"""Canonical, role-agnostic search-alert contract.

Shared by Guardian, Volunteer and Admin services against the SAME top-level
`alerts` collection -- there is no Guardian-only or Volunteer-only alert
store. A Guardian action (successful case creation) only ever *writes* an
alert intent here; delivery and targeting are Volunteer/Admin-side concerns
that are not yet integrated (no Volunteer device token or live-location
contract exists in this codebase yet). This module never claims a delivery
that did not happen: `delivered` starts false and only a future delivery
worker, wired against real Volunteer push tokens, may set it true.
"""
from firebase_admin import firestore

# Nearby is defined centrally so every consumer (a future proximity worker,
# tests, ops tooling) agrees on the same number. Subject to tuning during
# system testing -- change this one constant, not call sites.
PROXIMITY_RADIUS_METERS = 500

def general_alert(db, tx, *, case_id, event_id, status):
    """Persist the initial general alert intent for all active Volunteers.

    Called once, inside the same transaction as case creation, immediately
    after the case document is written and before anything else -- the
    initial general alert must never be delayed by the Guided Assistant.
    No Volunteer recipient list exists yet, so this is a broadcast-scoped
    intent (recipient_volunteer_id=None) for a future dispatcher to fan out
    once Volunteer device tokens are integrated.
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

    Not called anywhere yet: it requires a Volunteer live-location contract
    that does not exist in this codebase. Kept here, alongside the general
    alert it mirrors, as the documented shape a future proximity worker
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
