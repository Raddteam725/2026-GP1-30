"""Idempotent registration-expiry cleanup, with active-case deletion deferral.

Unknown legacy periods are neither guessed nor automatically deleted. Found
photos retain their separate end/match lifecycle. Terminal case statistics keep
the existing scrubber; registration expiry can scrub associated terminal debris
so identifiable information does not outlive its applicable registration.
"""
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import database, bucket
from .registration_retention import known_period, utc_now
from .found_reports import identified_report, minimal_completed, REUNITED
from .case_models import TERMINAL_STATUSES, age_group

CASE_RETENTION = timedelta(hours=24)

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

def expire_photos():
    """Compatibility job name: expires entire identifiable registrations, not photo age."""
    db = database()
    for guardian in db.collection('users').where(filter=FieldFilter('role', '==', 'guardian')).stream():
        for person in guardian.reference.collection('individuals').stream():
            @firestore.transactional
            def claim(tx):
                current = person.reference.get(transaction=tx)
                data = current.to_dict() or {}
                if not known_period(data) or data['registration_expires_at'] > utc_now():
                    return None
                prefix = f'guardians/{guardian.id}/individuals/{person.id}/'
                if data.get('guardian_id') != guardian.id or any(
                    data.get(field) and not data[field].startswith(prefix)
                    for field in ('photo_path', 'embedding_path')
                ):
                    return None
                if identified_report(db, data, tx) is not None:
                    return None
                # Read case records in the same transaction as the deletion fence.
                # Case creation/confirmation also reads and writes this registration.
                cases = list(db.collection('cases').where(filter=FieldFilter(
                    'individual_path', '==', person.reference.path)).stream(transaction=tx))
                associated = {c.id: c for c in cases}
                if data.get('active_case_id'):
                    c = db.collection('cases').document(data['active_case_id']).get(transaction=tx)
                    if not c.exists:
                        return None  # Unresolved reference: do not destroy case data.
                    associated[c.id] = c
                for case in associated.values():
                    linked = case.to_dict() or {}
                    if linked.get('scrubbed_at') is not None:
                        continue
                    if (linked.get('guardian_id') != guardian.id
                            or linked.get('individual_id') != person.id
                            or linked.get('event_id') != data.get('event_id')):
                        return None
                if any((c.to_dict() or {}).get('status') not in TERMINAL_STATUSES for c in associated.values()):
                    return None
                tx.update(person.reference, {'deleting': True})
                return data, list(associated.values())
            claimed = claim(db.transaction())
            if claimed is None:
                continue
            data, cases = claimed
            # Keep references and deletion fence on failure so the next job retries.
            if not all(_delete_blob(data.get(field)) for field in ('photo_path', 'embedding_path')):
                continue
            for case in cases:
                _scrub_case(db, case)
            # Embedded face_embedding and every other identifiable field leave
            # with the registration. Guardian account and other people are untouched.
            person.reference.delete()

def _delete_case_debris(db, case_id, guardian_id):
    # Everything found/alerted/notified about a case is deleted outright --
    # none of it is on the documented-statistics retain list, and it is not
    # the registered individual's own profile (untouched by this job).
    for report in db.collection("found_reports").where(filter=FieldFilter("case_id", "==", case_id)).stream():
        path = (report.to_dict() or {}).get("photo_path")
        if path and not _delete_blob(path):
            continue  # This found_report is the only reference to that photo
                       # -- leave both in place so the next run retries.
        data = report.to_dict() or {}
        if data.get('origin') == 'volunteer_found' and data.get('status') == REUNITED:
            report.reference.set(minimal_completed(data))
        else:
            report.reference.delete()
    for alert in db.collection("alerts").where(filter=FieldFilter("case_id", "==", case_id)).stream():
        alert.reference.delete()  # No PII, no Storage object -- always safe.
    if guardian_id:
        notes = db.collection("users").document(guardian_id).collection("notifications")
        for note in notes.where(filter=FieldFilter("case_id", "==", case_id)).stream():
            for receipt in note.reference.collection("deliveries").stream():
                receipt.reference.delete()
            note.reference.delete()
    # Every Volunteer can end up with a case-linked notification (materialized
    # lazily by VolunteerWorkflow.notifications_list for anyone who viewed
    # their list while the case was open), not only ones in `joined_by` --
    # scanning every Volunteer's own subcollection is the only way to reach
    # all of them without a copied index.
    for volunteer in db.collection("users").where(filter=FieldFilter("role", "==", "volunteer")).stream():
        notes = volunteer.reference.collection("volunteer_notifications")
        for note in notes.where(filter=FieldFilter("case_id", "==", case_id)).stream():
            for receipt in note.reference.collection("deliveries").stream():
                receipt.reference.delete()
            note.reference.delete()

def _scrub_case(db, doc):
    data = doc.to_dict() or {}
    # Debris cleanup always retries, even for an already-scrubbed case row:
    # a found_report whose Storage delete previously failed is the only
    # reference to that photo, and must keep being retried on every run,
    # independently of whether the case's own minimal record was already
    # written. Deleting already-gone debris is a harmless no-op.
    _delete_case_debris(db, doc.id, data.get("guardian_id"))
    if data.get("scrubbed_at") is not None:
        return  # Case row already minimized; only the debris retry above matters now.
    minimal = {
        "status": data.get("status"), "created_at": data.get("created_at"),
        "closed_at": data.get("closed_at"), "age_group": age_group(data["age"]) if isinstance(data.get("age"), int) else data.get("age_group"),
        "event_id": data.get("event_id"), "scrubbed_at": firestore.SERVER_TIMESTAMP,
    }
    # The one identifier the documented "Reunited Cases by Volunteer" Admin
    # statistic needs -- kept only for a Reunited case, never for any other
    # outcome, and never alongside anything identifying the individual/Guardian.
    if data.get("status") == "reunited" and data.get("handed_over_by"):
        minimal["handed_over_by"] = data["handed_over_by"]
    doc.reference.set(minimal)  # Full replace: every other field is gone.

def scrub_terminal_cases():
    db = database()
    cutoff = datetime.now(timezone.utc) - CASE_RETENTION
    # Requires the composite index in firestore.indexes.json (status ASC,
    # closed_at ASC on `cases`) once deployed against real Firestore --
    # equality + range on two different fields is not auto-indexed.
    for status in TERMINAL_STATUSES:
        due = db.collection("cases").where(filter=FieldFilter("status", "==", status)).where(
            filter=FieldFilter("closed_at", "<=", cutoff)
        ).stream()
        for doc in due:
            _scrub_case(db, doc)

def delete_finished_found_photos():
    """Retry interrupted synchronous deletion without touching missing cases."""
    db = database()
    for report in db.collection('found_reports').stream():
        data = report.to_dict()
        path = data.get('photo_path')
        if path and (data.get('ended') or data.get('matched_profile_id')) and _delete_blob(path):
            report.reference.update({'photo_path': firestore.DELETE_FIELD})

def run_all():
    """Convenience for manual/controlled invocation during development
    (`python -m app.cleanup`). The local server also invokes these jobs
    independently every minute."""
    run()
    expire_photos()
    scrub_terminal_cases()
    delete_finished_found_photos()

if __name__ == "__main__":
    run_all()
