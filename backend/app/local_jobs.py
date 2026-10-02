"""Approved local-only maintenance loop, one worker per development server.

No separate backend or Firebase project. Every job retries on the next minute;
a failure in one job does not stop the others. Deployment must not enable this
in multiple Uvicorn workers without a shared scheduler/lease.
"""
import threading
from . import jobs

INTERVAL_SECONDS = 60

def run_once():
    jobs.run_cleanup()
    jobs.run_retry()

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
