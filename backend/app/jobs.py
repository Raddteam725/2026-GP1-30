"""Maintenance jobs, split into a safe retry group and a destructive cleanup group.

Cloud Run Jobs run one group per process: `python -m app.jobs retry` (every 15
minutes) and `python -m app.jobs cleanup` (hourly). Pushes are sent inline
because queued background threads die when the job process exits. Local
development runs both groups through local_jobs.LocalJobs.
"""
import argparse
import logging
import os
import sys
from . import cleanup, delivery_queue
from .firebase import database
from .volunteer_alerts import dispatch
from .push import retry_guardian_alerts
from .case_models import STAGES
from google.cloud.firestore_v1.base_query import FieldFilter

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

# Resolvers, not functions, so each job is looked up at call time and can be monkeypatched.
RETRY_JOBS = (lambda: retry_alerts, lambda: retry_guardian_alerts)
CLEANUP_JOBS = (lambda: cleanup.run, lambda: cleanup.expire_photos,
                lambda: cleanup.scrub_terminal_cases, lambda: cleanup.delete_finished_found_photos)

def _run_group(group):
    succeeded = True
    for resolve in group:
        job = resolve()
        try:
            job()
        except Exception as error:
            succeeded = False
            logging.getLogger(__name__).warning('Job %s failed (%s)', getattr(job, '__name__', 'job'), type(error).__name__)
    return succeeded

def run_retry():
    return _run_group(RETRY_JOBS)

def run_cleanup():
    return _run_group(CLEANUP_JOBS)

def main(argv=None):
    parser = argparse.ArgumentParser(prog='python -m app.jobs', description='Run one Radd maintenance job group.')
    parser.add_argument('group', choices=('retry', 'cleanup'))
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO)
    mode = os.environ.get('RADD_DELIVERY_MODE')
    if not mode:
        os.environ['RADD_DELIVERY_MODE'] = 'inline'
    elif mode == 'queue':
        sys.exit('RADD_DELIVERY_MODE=queue is not allowed for jobs: queued pushes die when the process exits')
    delivery_queue.delivery_mode()
    succeeded = run_retry() if args.group == 'retry' else run_cleanup()
    return 0 if succeeded else 1

if __name__ == '__main__':
    sys.exit(main())
