"""Approved local-only maintenance loop, one worker per development server.

No separate backend or Firebase project. Every job retries on the next minute;
a failure in one job does not stop the others. Deployment must not enable this
in multiple Uvicorn workers without a shared scheduler/lease.
"""
import logging
import threading
from . import cleanup
from .firebase import database
from .volunteer_alerts import dispatch
from .push import retry_guardian_alerts
from .case_models import STAGES
from google.cloud.firestore_v1.base_query import FieldFilter

INTERVAL_SECONDS = 60

def retry_alerts():
    db = database()
    for event in db.collection('events').where(filter=FieldFilter('active', '==', True)).stream():
        for case in db.collection('cases').where(filter=FieldFilter('event_id', '==', event.id)).stream():
            status = case.to_dict().get('status')
            if status in (*STAGES, 'cancelled', 'resolved'):
                try:
                    dispatch(db, case.id, matched=status in STAGES[2:])
                except Exception as error:
                    logging.getLogger(__name__).warning('Volunteer alert retry failed (%s)', type(error).__name__)

def run_once():
    for job in (cleanup.run, cleanup.expire_photos, cleanup.scrub_terminal_cases,
                cleanup.delete_finished_found_photos, retry_alerts, retry_guardian_alerts):
        try:
            job()
        except Exception as error:
            logging.getLogger(__name__).warning('Local job %s failed (%s); retry next minute', job.__name__, type(error).__name__)

class LocalJobs:
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
