"""Two independent, idempotent retention jobs. Deliberately NOT wired to any
scheduler/deployment mechanism here -- during development they are invoked
directly (by tests, or manually via `python -m app.cleanup` for controlled
verification against real Firebase). Whatever eventually triggers them on a
schedule in production calls these same functions unchanged.

- expire_photos(): a registered individual's photo is only ever current for
  24 hours from its own capture time (never from an event day/date boundary).
  Physically deletes the Storage object and only then clears the stale
  Firestore reference. See app.service.PHOTO_FRESHNESS/photo_expired -- the
  backend already refuses to serve or rely on an expired photo even before
  this job next runs; this job's job is freeing the Storage object itself.
- scrub_terminal_cases(): 24 hours after a case reaches a terminal status,
  every identifying/personal field is removed from the shared `cases` row
  (and everything found/alerted/notified about it elsewhere is deleted
  outright), leaving only the minimum fields the documented Admin statistics
  need. The registered individual's own profile is untouched by this --
  its lifecycle is governed solely by expire_photos()/the Guardian's own
  explicit delete, never by case status.

Storage-deletion contract, load-bearing for both jobs: a Firestore reference
to a Storage object is never cleared/removed unless that object was actually
deleted (or was already gone). If the delete fails, the reference is left
exactly as it was so the next run retries the same object -- this must never
silently orphan a blob that a person can no longer be pointed at, nor must a
transient failure make it look like nothing needs deleting anymore. See
`_delete_blob` and every one of its call sites.
"""
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import database, bucket
from .service import PHOTO_FRESHNESS
from .case_models import TERMINAL_STATUSES

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
    db = database()
    cutoff = datetime.now(timezone.utc) - PHOTO_FRESHNESS
    # No collection-group index/query is assumed available; walk the same
    # guardian -> individuals path the rest of the app already uses (e.g.
    # VolunteerWorkflow.registrations), scoped server-side to Firestore's own
    # `<=` filter on the authoritative capture timestamp.
    for guardian in db.collection("users").where(filter=FieldFilter("role", "==", "guardian")).stream():
        stale = guardian.reference.collection("individuals").where(
            filter=FieldFilter("photo_captured_at", "<=", cutoff)
        ).stream()
        for person in stale:
            data = person.to_dict() or {}
            path = data.get("photo_path")
            if not path:
                continue  # Already cleared by an earlier run -- idempotent no-op.
            if not _delete_blob(path):
                continue  # Storage delete failed: reference stays; retried next run.
            @firestore.transactional
            def clear(tx, ref=person.reference, expected=path):
                # Re-read inside the transaction: if the Guardian captured a
                # NEW photo since this sweep started, photo_path now points
                # at that replacement, not `expected` -- in that case this is
                # a no-op, so an older, already-completed delete of the OLD
                # blob can never reach into the record and remove the new one.
                current = ref.get(transaction=tx).to_dict() or {}
                if current.get("photo_path") == expected:
                    tx.update(ref, {"photo_path": firestore.DELETE_FIELD})
            clear(db.transaction())

def _delete_case_debris(db, case_id, guardian_id):
    # Everything found/alerted/notified about a case is deleted outright --
    # none of it is on the documented-statistics retain list, and it is not
    # the registered individual's own profile (untouched by this job).
    for report in db.collection("found_reports").where(filter=FieldFilter("case_id", "==", case_id)).stream():
        path = (report.to_dict() or {}).get("photo_path")
        if path and not _delete_blob(path):
            continue  # This found_report is the only reference to that photo
                       # -- leave both in place so the next run retries.
        report.reference.delete()
    for alert in db.collection("alerts").where(filter=FieldFilter("case_id", "==", case_id)).stream():
        alert.reference.delete()  # No PII, no Storage object -- always safe.
    if guardian_id:
        notes = db.collection("users").document(guardian_id).collection("notifications")
        for note in notes.where(filter=FieldFilter("case_id", "==", case_id)).stream():
            note.reference.delete()
    # Every Volunteer can end up with a case-linked notification (materialized
    # lazily by VolunteerWorkflow.notifications_list for anyone who viewed
    # their list while the case was open), not only ones in `joined_by` --
    # scanning every Volunteer's own subcollection is the only way to reach
    # all of them without a copied index.
    for volunteer in db.collection("users").where(filter=FieldFilter("role", "==", "volunteer")).stream():
        notes = volunteer.reference.collection("volunteer_notifications")
        for note in notes.where(filter=FieldFilter("case_id", "==", case_id)).stream():
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
        "closed_at": data.get("closed_at"), "age_group": data.get("age_group"),
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

def run_all():
    """Convenience for manual/controlled invocation during development
    (`python -m app.cleanup`). Not wired to any scheduler -- deployment
    decides how/when this runs; order here does not matter, each job is
    independent and idempotent."""
    run()
    expire_photos()
    scrub_terminal_cases()

if __name__ == "__main__":
    run_all()
