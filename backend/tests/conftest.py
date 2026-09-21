"""Deterministic dispatch for isolated domain tests; production uses workers.

The worker itself is tested separately with real threads and synchronization.
"""
import sys
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

@pytest.fixture(autouse=True)
def inline_delivery(monkeypatch):
    from app import delivery_queue
    monkeypatch.setattr(delivery_queue, 'submit', lambda key, operation: operation())
