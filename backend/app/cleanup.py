from datetime import datetime, timedelta, timezone
from firebase_admin import firestore
from .firebase import database, bucket
from .found_reports import found_status, IDENTIFYING

def _delete_blob(path):
    if not path:
        return True
    try:
        blob = bucket().blob(path)
        if blob.exists():
            blob.delete()
        return True
    except Exception:
        return False

def run():
    for doc in database().collection("photo_cleanup").stream():
        path = doc.to_dict().get("path")
        if _delete_blob(path):
            doc.reference.delete()

def delete_finished_found_photos():
    db = database()
    for report in db.collection('found_reports').stream():
        data = report.to_dict()
        path = data.get('photo_path')
        if path and (data.get('ended') or data.get('matched_profile_id')) and _delete_blob(path):
            report.reference.update({'photo_path': firestore.DELETE_FIELD})

ABANDONED_ATTEMPT_AGE = timedelta(hours=2)

def end_abandoned_found_attempts(now=None):
    db = database()
    cutoff = (now or datetime.now(timezone.utc)) - ABANDONED_ATTEMPT_AGE

    def abandoned(data):
        created = data.get('created_at')
        return (bool(data.get('photo_path')) and not data.get('ended')
                and not data.get('matched_profile_id')
                and found_status(data) == IDENTIFYING
                and isinstance(created, datetime) and created <= cutoff)

    for report in db.collection('found_reports').stream():
        if not abandoned(report.to_dict() or {}):
            continue

        @firestore.transactional
        def end(tx):
            current = report.reference.get(transaction=tx).to_dict() or {}
            if not abandoned(current):
                return None
            tx.update(report.reference, {'ended': True, 'ended_at': firestore.SERVER_TIMESTAMP})
            return current['photo_path']
        path = end(db.transaction())
        if path and _delete_blob(path):
            report.reference.update({'photo_path': firestore.DELETE_FIELD})

def run_all():
    run()
    delete_finished_found_photos()
    end_abandoned_found_attempts()

if __name__ == "__main__":
    run_all()
