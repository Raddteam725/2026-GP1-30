"""Read state shared by the two ownership-scoped notification collections."""
from firebase_admin import firestore


def read_update(data):
    return {'read_at': firestore.SERVER_TIMESTAMP} if data.get('read_at') is None else {}


def mark_all_read(db, collection, *, event_id=None):
    unread = [doc for doc in collection.stream()
              if (event_id is None or doc.to_dict().get('event_id') == event_id)
              and read_update(doc.to_dict())]
    # A normal inbox uses one batch; split larger histories at the write limit.
    for start in range(0, len(unread), 500):
        batch = db.batch()
        for doc in unread[start:start + 500]:
            batch.update(doc.reference, read_update(doc.to_dict()))
        batch.commit()
