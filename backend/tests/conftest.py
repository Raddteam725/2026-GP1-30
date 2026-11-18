"""Deterministic dispatch for isolated domain tests; production uses workers.

The worker itself is tested separately with real threads and synchronization.
"""
import sys
from pathlib import Path
import pytest
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

@pytest.fixture(autouse=True)
def inline_delivery(monkeypatch):
    from app import delivery_queue
    monkeypatch.setattr(delivery_queue, 'submit', lambda key, operation: operation())

@pytest.fixture(autouse=True)
def verified_firebase_accounts(monkeypatch):
    # Domain tests use synthetic established accounts; never reach live Auth.
    # Security tests override this SDK boundary to exercise unverified, stale,
    # disabled and unavailable identities with the real authorization helper.
    from app import firebase
    monkeypatch.setattr(firebase, 'firebase_app', lambda: None)
    monkeypatch.setattr(firebase.auth, 'get_user', lambda uid, **kwargs:
        SimpleNamespace(uid=uid, email=uid + '@example.test', email_verified=True,
                        disabled=False, tokens_valid_after_timestamp=0))
