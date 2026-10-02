"""Immediate dispatch; durable Firestore records remain the retry source.

RADD_DELIVERY_MODE=queue (default) hands work to bounded background threads for
the long-running local FastAPI process. RADD_DELIVERY_MODE=inline runs it in the
calling thread before returning, for Cloud Run services and jobs where threads
get no CPU after the response or die when the process exits. When unset on
Cloud Run (K_SERVICE is set), the default is inline.
"""
import logging
import os
from queue import Queue, Full
from threading import Lock, Thread

class ImmediateDelivery:
    def __init__(self, workers=4, capacity=256):
        self.queue = Queue(capacity)
        self.lock = Lock()
        self.pending = set()
        self.started = False
        self.workers = workers

    def submit(self, key, operation):
        with self.lock:
            if key in self.pending:
                return True
            if not self.started:
                for _ in range(self.workers):
                    Thread(target=self._work, daemon=True, name='radd-delivery').start()
                self.started = True
            self.pending.add(key)
            try:
                self.queue.put_nowait((key, operation))
            except Full:
                self.pending.remove(key)
                logging.getLogger('uvicorn.error').warning('Delivery queue full; durable event pending retry')
                return False
        return True

    def _work(self):
        while True:
            key, operation = self.queue.get()
            try:
                operation()
            except Exception as error:
                logging.getLogger('uvicorn.error').warning('Delivery pending retry (%s)', type(error).__name__)
            finally:
                with self.lock:
                    self.pending.remove(key)
                self.queue.task_done()

dispatcher = ImmediateDelivery()
inline_lock = Lock()
inline_pending = set()

def delivery_mode():
    mode = os.getenv('RADD_DELIVERY_MODE') or ('inline' if os.getenv('K_SERVICE') else 'queue')
    if mode not in ('queue', 'inline'):
        raise ValueError('RADD_DELIVERY_MODE must be "queue" or "inline"')
    return mode

def submit(key, operation):
    if delivery_mode() == 'queue':
        return dispatcher.submit(key, operation)
    with inline_lock:
        if key in inline_pending:
            return True
        inline_pending.add(key)
    try:
        operation()
    except Exception as error:
        logging.getLogger('uvicorn.error').warning('Delivery pending retry (%s)', type(error).__name__)
    finally:
        with inline_lock:
            inline_pending.remove(key)
    return True
