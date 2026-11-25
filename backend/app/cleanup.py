"""Idempotent maintenance cleanup for completed Release 1 functionality.

Release 2 retention work is not performed here: automatic deletion of
identifiable registration data at the end of the selected registration period
(PBI 37) and the 24-hour minimization of terminal cases with their linked
records (PBIs 35/37). An expired registration stays stored and is only excluded
from new reports and matching by registration_retention. What remains: the
orphaned-photo queue (PBI 8) and the found-photo lifecycle (PBI 20).
"""
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore
from .firebase import database, bucket
from .found_reports import found_status, IDENTIFYING

def _delete_blob(path):
    """True: safe to remove the (only) Firestore reference to `path` -- the
    object is gone or never existed. False: deletion failed; the caller MUST
    leave the reference in place so this is retried, not silently dropped."""
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
    """Orphaned-photo queue purge (a replaced/failed-save photo's old blob)."""
    for doc in database().collection("photo_cleanup").stream():
        path = doc.to_dict().get("path")
        if _delete_blob(path):
            doc.reference.delete()
        # Else: left in the queue for the next run -- same never-clear-on-
        # failure rule as everywhere else in this module.

def delete_finished_found_photos():
    """Retry interrupted synchronous deletion without touching missing cases."""
    db = database()
    for report in db.collection('found_reports').stream():
        data = report.to_dict()
        path = data.get('photo_path')
        if path and (data.get('ended') or data.get('matched_profile_id')) and _delete_blob(path):
            report.reference.update({'photo_path': firestore.DELETE_FIELD})

# Backstop only. A Volunteer leaving the identification flow ends the attempt
# (and deletes its photo) at once, and the app ends any attempt left over from
# an interrupted session on its next load. This catches the remainder: devices
# that never come back. No real on-site attempt stays open this long.
ABANDONED_ATTEMPT_AGE = timedelta(hours=2)

def end_abandoned_found_attempts(now=None):
    """End still-identifying Found attempts older than ABANDONED_ATTEMPT_AGE
    and delete their photo, exactly as an explicit End Identification does.
    Confirmed/verifying/reunited reports and manual (photo-less) reports are
    never touched."""
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
                return None  # Confirmed or ended meanwhile: leave it alone.
            tx.update(report.reference, {'ended': True, 'ended_at': firestore.SERVER_TIMESTAMP})
            return current['photo_path']
        path = end(db.transaction())
        # On a failed Storage delete the path stays; delete_finished_found_photos
        # retries it on the next run (the report is now ended).
        if path and _delete_blob(path):
            report.reference.update({'photo_path': firestore.DELETE_FIELD})

def run_all():
    """Convenience for manual/controlled invocation during development
    (`python -m app.cleanup`). The local server also invokes these jobs
    independently every minute."""
    run()
    delete_finished_found_photos()
    end_abandoned_found_attempts()

if __name__ == "__main__":
    run_all()
