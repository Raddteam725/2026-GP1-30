"""Minimal in-memory Firestore/Storage fake shared by the isolated service tests.

Not a Firestore emulator: enough surface (documents, merge/update, filtered
queries with limit, and a transaction that is just the db itself once
firestore.transactional is monkeypatched to identity) for the app.service /
app.cases transactional functions to run against. Never touches production.

SERVER_TIMESTAMP is resolved to a real `datetime.now(timezone.utc)` at write
time (mirroring what the real Firestore server does on commit) rather than
stored as the literal sentinel -- retention/expiry code needs to do real
datetime arithmetic on fields like `closed_at` and `photo_captured_at` after
reading them back, exactly as it would against production Firestore.
DELETE_FIELD is likewise honored on `update()`/merge writes.
"""
from datetime import datetime, timezone
from firebase_admin import firestore as _firestore

def _resolve(value):
    if isinstance(value, dict):
        return {k: _resolve(v) for k, v in value.items()}
    if value is _firestore.SERVER_TIMESTAMP:
        return datetime.now(timezone.utc)
    return value

class Snapshot:
    def __init__(self, ref):
        self.reference = ref
        self.id = ref.path.split("/")[-1]
        self.exists = ref.path in ref.db.data
    def to_dict(self):
        value = self.reference.db.data.get(self.reference.path)
        return dict(value) if value is not None else None

class Reference:
    def __init__(self, db, path):
        self.db, self.path = db, path
        self.id = path.split("/")[-1]
    def get(self, transaction=None):
        return Snapshot(self)
    def collection(self, name):
        return Collection(self.db, self.path + "/" + name)
    def set(self, value, merge=False):
        self.db.set(self, value, merge)
    def update(self, value):
        self.db.update(self, value)
    def delete(self):
        self.db.data.pop(self.path, None)

def _predicate(filter):
    # `a is not None` guards ordering ops so a document missing the field is
    # excluded rather than raising -- matching real Firestore, which never
    # matches an inequality filter against an absent field.
    ops = {
        "==": lambda a, b: a == b,
        "!=": lambda a, b: a != b,
        "<": lambda a, b: a is not None and a < b,
        "<=": lambda a, b: a is not None and a <= b,
        ">": lambda a, b: a is not None and a > b,
        ">=": lambda a, b: a is not None and a >= b,
        "in": lambda a, b: a in b,
    }
    op = ops[filter.op_string]
    return lambda data: op(data.get(filter.field_path), filter.value)

class Query:
    def __init__(self, db, path, predicate, cap=None):
        self.db, self.path, self.predicate, self.cap = db, path, predicate, cap
    def where(self, filter):
        extra = _predicate(filter)
        combined = lambda data, base=self.predicate: base(data) and extra(data)
        return Query(self.db, self.path, combined, self.cap)
    def limit(self, n):
        return Query(self.db, self.path, self.predicate, n)
    def stream(self, transaction=None):
        docs = [d for d in Collection(self.db, self.path).stream() if self.predicate(d.to_dict() or {})]
        return docs[: self.cap] if self.cap is not None else docs

class Collection:
    def __init__(self, db, path):
        self.db, self.path = db, path
    def document(self, name=None):
        self.db.counter += 1
        return Reference(self.db, self.path + "/" + (name or str(self.db.counter)))
    def stream(self, transaction=None):
        prefix = self.path + "/"
        return [Snapshot(Reference(self.db, p)) for p in list(self.db.data) if p.startswith(prefix) and "/" not in p[len(prefix):]]
    def add(self, value):
        self.db.set(self.document(), value)
    def where(self, filter):
        return Query(self.db, self.path, _predicate(filter))

class Database:
    def __init__(self):
        self.data, self.counter = {}, 0
    def collection(self, name):
        return Collection(self, name)
    def transaction(self):
        return self
    def set(self, ref, value, merge=False):
        resolved = _resolve(value)
        base = dict(self.data.get(ref.path, {})) if merge else {}
        for k, v in resolved.items():
            if v is _firestore.DELETE_FIELD:
                base.pop(k, None)
            else:
                base[k] = v
        self.data[ref.path] = base
    def update(self, ref, value):
        self.set(ref, value, merge=True)

class Blob:
    def __init__(self, store, path, failures):
        self.store, self.path, self.failures = store, path, failures
    def upload_from_string(self, data, content_type):
        assert content_type == "image/jpeg"
        self.store[self.path] = data
    def download_as_bytes(self):
        return self.store[self.path]
    def exists(self):
        return self.path in self.store
    def delete(self):
        if self.path in self.failures:
            # Fails exactly once per fail_next_delete() call -- simulates one
            # transient Storage error, then succeeds on the next attempt.
            self.failures.remove(self.path)
            raise IOError("simulated transient storage failure")
        self.store.pop(self.path)

class Bucket:
    def __init__(self):
        self.data = {}
        self.failures = set()
    def blob(self, path):
        return Blob(self.data, path, self.failures)
    def fail_next_delete(self, path):
        """Test-only: makes the next delete() of this exact path raise once."""
        self.failures.add(path)
