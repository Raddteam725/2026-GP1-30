"""Reconciliation and retention jobs -- never the normal delivery path.

Normal delivery is: commit -> durable record -> immediate push attempt inside
the same request (see app.delivery). These jobs only (a) retry the pushes FCM
never accepted, which the delivery receipts make an exact, idempotent
operation, and (b) apply the retention rules in app.cleanup.

`run_once` is the one entry point. Locally (`run_dev.py`, RADD_LOCAL_JOBS=1)
the `LocalJobs` thread calls it every minute -- an approved development
convenience only. The production API service must NOT run that thread:
Cloud Run gives a request-serving container no guaranteed CPU between
requests, so an in-process loop is not durable there. Deployment instead
connects a managed scheduler (Cloud Scheduler) to the maintenance endpoint
in app.main, which calls the same `run_once` -- the interface is this
module, not the thread.
"""
import logging
import threading
from datetime import datetime, timezone
from . import cleanup
from .firebase import database
from .push import retry_recent
from .volunteer_alerts import dispatch
from .case_models import STAGES, TERMINAL_STATUSES
from .cleanup import CASE_RETENTION
from google.cloud.firestore_v1.base_query import FieldFilter

INTERVAL_SECONDS = 60

def retry_alerts():
    """Re-attempt Volunteer pushes for every case of the active event(s):
    open cases (new/match alerts) and recently closed ones (closure notices).
    Delivery receipts make an already-accepted push a no-op."""
    db = database()
    cutoff = datetime.now(timezone.utc) - CASE_RETENTION
    for event in db.collection('events').where(filter=FieldFilter('active', '==', True)).stream():
        for case in db.collection('cases').where(filter=FieldFilter('event_id', '==', event.id)).stream():
            data = case.to_dict() or {}
            status = data.get('status')
            closed_at = data.get('closed_at')
            due = status in STAGES and status not in TERMINAL_STATUSES
            due = due or (status in TERMINAL_STATUSES and status != 'reunited'
                          and isinstance(closed_at, datetime) and closed_at >= cutoff)
            if not due:
                continue
            try:
                dispatch(db, case.id)
            except Exception as error:
                logging.getLogger(__name__).warning('Volunteer alert retry failed (%s)', type(error).__name__)

def retry_guardian_pushes():
    """Same reconciliation for the Guardian direction (see push.retry_recent)."""
    retry_recent(database())

def run_once():
    for job in (cleanup.run, cleanup.expire_photos, cleanup.scrub_terminal_cases,
                cleanup.delete_finished_found_photos, retry_alerts, retry_guardian_pushes):
        try:
            job()
        except Exception as error:
            logging.getLogger(__name__).warning('Maintenance job %s failed (%s); retried on the next run', job.__name__, type(error).__name__)

class LocalJobs:
    """Development-only in-process scheduler (see module docstring)."""
    def __init__(self):
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self._run, name='radd-local-jobs', daemon=True)
    def start(self):
        self.thread.start()
    def _run(self):
        while not self.stop_event.is_set():
            run_once()
            self.stop_event.wait(INTERVAL_SECONDS)
    def stop(self):
        self.stop_event.set()
        self.thread.join(timeout=5)
