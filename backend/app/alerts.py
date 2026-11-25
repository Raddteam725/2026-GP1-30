from firebase_admin import firestore

PROXIMITY_RADIUS_METERS = 500

def general_alert(db, tx, *, case_id, event_id, status):
    ref = db.collection("alerts").document()
    tx.set(ref, {
        "case_id": case_id, "event_id": event_id, "kind": "general",
        "status": status, "recipient_volunteer_id": None,
        "proximity_eligible": None, "distance_meters": None,
        "delivered": False, "created_at": firestore.SERVER_TIMESTAMP,
    })
    return ref.id
