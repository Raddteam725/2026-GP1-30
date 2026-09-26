from threading import Event
from app.delivery_queue import ImmediateDelivery

def test_slow_delivery_does_not_block_submission_and_duplicate_is_coalesced():
    worker = ImmediateDelivery(workers=1, capacity=1)
    started, finish, completed = Event(), Event(), Event()
    calls = []
    def send():
        calls.append('send')
        started.set()
        finish.wait(2)
        completed.set()
    try:
        assert worker.submit('event', send)
        assert started.wait(1)  # Immediate attempt, no maintenance timer.
        assert not completed.is_set()  # Caller already returned while send waits.
        assert worker.submit('event', send)
        assert calls == ['send']
    finally:
        finish.set()
        assert completed.wait(1)

def test_worker_queue_is_bounded_and_does_not_claim_delivery_when_full():
    worker = ImmediateDelivery(workers=1, capacity=1)
    started, finish = Event(), Event()
    def slow():
        started.set()
        finish.wait(2)
    try:
        assert worker.submit('first', slow)
        assert started.wait(1)
        assert worker.submit('second', lambda: None)
        assert worker.submit('third', lambda: None) is False
    finally:
        finish.set()
