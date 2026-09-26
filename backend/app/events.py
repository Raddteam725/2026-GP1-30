"""One active event per deployment. Bootstrap is explicit setup, never an API side effect."""
from fastapi import HTTPException
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

def active_event(db, transaction=None):
    docs = list(db.collection("events").where(filter=FieldFilter("active", "==", True)).limit(2).stream(transaction=transaction))
    if len(docs) > 1:
        raise HTTPException(503, detail="multiple_active_events")
    if not docs:
        raise HTTPException(503, detail="event_unavailable")
    return docs[0]

def bootstrap_development_event(db):
    # Singleton setup lock makes simultaneous bootstrap attempts serialize.
    lock = db.collection("configuration").document("event_bootstrap")
    ref = db.collection("events").document()
    @firestore.transactional
    def bootstrap(tx):
        lock.get(transaction=tx)
        docs = list(db.collection("events").where(filter=FieldFilter("active", "==", True)).limit(2).stream(transaction=tx))
        if len(docs) > 1:
            raise HTTPException(503, detail="multiple_active_events")
        if docs:
            return docs[0].id
        tx.set(ref, {"name": "Radd Sprint 0 Development", "active": True,
            "environment": "development", "created_at": firestore.SERVER_TIMESTAMP})
        tx.set(lock, {"event_id": ref.id, "updated_at": firestore.SERVER_TIMESTAMP})
        return ref.id
    return bootstrap(db.transaction())
