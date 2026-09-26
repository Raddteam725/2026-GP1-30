"""Immediate local dispatch; durable Firestore records remain the retry source.

This bounded executor is for the current long-running FastAPI process. A cloud
deployment must replace this transport with managed execution, not rely on an
in-process queue surviving instance termination.
"""
import logging
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

def submit(key, operation):
    return dispatcher.submit(key, operation)
