import sys
from pathlib import Path
import pytest
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

@pytest.fixture(autouse=True)
def no_face_model(monkeypatch):
    from app import face_matching
    monkeypatch.setattr(face_matching, 'get_engine', lambda: None)

@pytest.fixture(autouse=True)
def inline_delivery(monkeypatch):
    from app import delivery_queue
    monkeypatch.setattr(delivery_queue, 'submit', lambda key, operation: operation())

@pytest.fixture(autouse=True)
def verified_firebase_accounts(monkeypatch):
    from app import firebase
    monkeypatch.setattr(firebase, 'firebase_app', lambda: None)
    monkeypatch.setattr(firebase.auth, 'get_user', lambda uid, **kwargs:
        SimpleNamespace(uid=uid, email=uid + '@example.test', email_verified=True,
                        disabled=False, tokens_valid_after_timestamp=0))
