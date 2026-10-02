"""Maintenance jobs, split into a safe retry group and a destructive cleanup group.

Cloud Run Jobs run one group per process: `python -m app.jobs retry` (every 15
minutes) and `python -m app.jobs cleanup` (hourly). Pushes are sent inline
because queued background threads die when the job process exits. Local
development runs both groups through local_jobs.LocalJobs. Cleanup holds an
expiring Firestore lease so overlapping runs never delete at the same time.
"""
import argparse
import logging
import os
import sys
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from firebase_admin import firestore
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

LEASE_COLLECTION, LEASE_DOCUMENT = 'configuration', 'cleanup_lock'
# The cleanup Cloud Run Job's task timeout must be shorter than this lease
# (planned: 15 minutes), so a run can never outlive the lease it holds.
CLEANUP_LEASE_SECONDS = 1200

def _lease(db):
    return db.collection(LEASE_COLLECTION).document(LEASE_DOCUMENT)

def acquire_cleanup_lease(db, owner, now):
    ref = _lease(db)
    @firestore.transactional
    def acquire(tx):
        data = ref.get(transaction=tx).to_dict()
        if data and data.get('owner') != owner and data.get('expires_at') and data['expires_at'] > now:
            return False
        tx.set(ref, {'owner': owner, 'expires_at': now + timedelta(seconds=CLEANUP_LEASE_SECONDS),
                     'acquired_at': firestore.SERVER_TIMESTAMP})
        return True
    return acquire(db.transaction())

def release_cleanup_lease(db, owner):
    ref = _lease(db)
    @firestore.transactional
    def release(tx):
        data = ref.get(transaction=tx).to_dict()
        if data and data.get('owner') == owner:
            tx.delete(ref)
    release(db.transaction())

def run_cleanup():
    owner = uuid4().hex
    log = logging.getLogger(__name__)
    try:
        db = database()
        acquired = acquire_cleanup_lease(db, owner, datetime.now(timezone.utc))
    except Exception as error:
        log.warning('Cleanup lease unavailable (%s); no cleanup ran', type(error).__name__)
        return False
    if not acquired:
        log.info('Cleanup skipped; another run holds the lease')
        return True
    try:
        return _run_group(CLEANUP_JOBS)
    finally:
        try:
            release_cleanup_lease(db, owner)
        except Exception as error:
            log.warning('Cleanup lease release failed (%s); it expires on its own', type(error).__name__)

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
