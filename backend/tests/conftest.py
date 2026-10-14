"""Deterministic dispatch for isolated domain tests; production uses workers.

The worker itself is tested separately with real threads and synchronization.
"""
import sys
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

@pytest.fixture(autouse=True)
def no_face_model(monkeypatch):
    # Domain tests never load the real face model, even when it is installed;
    # face-matching tests inject a fake engine explicitly.
    from app import face_matching
    monkeypatch.setattr(face_matching, 'get_engine', lambda: None)

@pytest.fixture(autouse=True)
def inline_delivery(monkeypatch):
    from app import delivery_queue
    monkeypatch.setattr(delivery_queue, 'submit', lambda key, operation: operation())
