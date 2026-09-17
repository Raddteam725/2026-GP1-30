"""Minimal in-memory Firestore/Storage fake shared by the isolated service tests.

Not a Firestore emulator: enough surface (documents, merge/update, ==-filtered
queries with limit, and a transaction that is just the db itself once
firestore.transactional is monkeypatched to identity) for the app.service /
app.cases transactional functions to run against. Never touches production.
"""

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
    def delete(self):
        self.db.data.pop(self.path, None)

class Query:
    def __init__(self, db, path, predicate, cap=None):
        self.db, self.path, self.predicate, self.cap = db, path, predicate, cap
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
        op = {"==": lambda a, b: a == b}[filter.op_string]
        return Query(self.db, self.path, lambda data: op(data.get(filter.field_path), filter.value))

class Database:
    def __init__(self):
        self.data, self.counter = {}, 0
    def collection(self, name):
        return Collection(self, name)
    def transaction(self):
        return self
    def set(self, ref, value, merge=False):
        self.data[ref.path] = (self.data.get(ref.path, {}) if merge else {}) | value
    def update(self, ref, value):
        self.set(ref, value, merge=True)

class Blob:
    def __init__(self, store, path):
        self.store, self.path = store, path
    def upload_from_string(self, data, content_type):
        assert content_type == "image/jpeg"
        self.store[self.path] = data
    def download_as_bytes(self):
        return self.store[self.path]
    def exists(self):
        return self.path in self.store
    def delete(self):
        self.store.pop(self.path)

class Bucket:
    def __init__(self):
        self.data = {}
    def blob(self, path):
        return Blob(self.data, path)
