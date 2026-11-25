import base64
import binascii
import hashlib
import io
import secrets
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from PIL import Image, ImageOps, UnidentifiedImageError
from fastapi import HTTPException
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from .firebase import database, bucket, require_verified_email
from .events import active_event
from . import face_matching

Image.MAX_IMAGE_PIXELS = 20_000_000

def assert_guardian_role(token, profile):
    if token.get("role") not in (None, "guardian") or profile.get("role") != "guardian":
        raise HTTPException(403, detail="guardian_required")
    if profile.get("active") is False:
        raise HTTPException(403, detail="account_inactive")

def owned_registration(data, uid):
    if not data or data.get("guardian_id") != uid:
        raise HTTPException(404, detail="not_found")
    return data

def ensure_deletable(data):
    if data.get("active_case_id") or data.get("active_found_report_id"):
        raise HTTPException(409, detail="active_case")

from .registration_retention import registration_available, establish, reschedule, edit_options


def photo_expired(data, db=None, tx=None, *, case_context=False):
    return not registration_available(data, db, tx, case_context=case_context)

def public_individual(doc, db=None):
    data = doc.to_dict()
    return {**{k: data[k] for k in ("full_name", "age", "gender", "relationship")},
        "relationship_other": data.get("relationship_other"),
        "id": doc.id, "active_case_id": data.get("active_case_id"),
        "registration_started_at": data.get("registration_started_at"),
        "registration_expires_at": data.get("registration_expires_at"),
        "registration_period_id": data.get("registration_period_id"),
        "registration_duration_hours": data.get("registration_duration_hours"),
        "photo_expired": photo_expired(data, db)}

def normalize_photo(encoded):
    try:
        raw = base64.b64decode(encoded, validate=True)
        if len(raw) > 8_000_000:
            raise ValueError()
        with Image.open(io.BytesIO(raw)) as image:
            if image.format not in ("JPEG", "PNG"):
                raise ValueError()
            image.load()
            image = ImageOps.exif_transpose(image).convert("RGB")
            image.thumbnail((1600, 1600))
            output = io.BytesIO()
            image.save(output, format="JPEG", quality=90)
            return output.getvalue()
    except (ValueError, binascii.Error, UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise HTTPException(422, detail="invalid_photo") from None

class GuardianService:
    def __init__(self, token):
        self.token = token
        self.uid = token["uid"]
        self.db = database()
        self.user = self.db.collection("users").document(self.uid)
        self._email_checked = False

    def verified_email(self):
        if not self._email_checked:
            require_verified_email(self.token)
            self._email_checked = True

    def account_role(self):
        doc = self.user.get()
        if not doc.exists:
            raise HTTPException(404, detail="profile_missing")
        role = doc.to_dict().get("role")
        if role not in ("guardian", "volunteer") or self.token.get("role") not in (None, role):
            raise HTTPException(403, detail="role_unresolved")
        return {"role": role}

    def current_event(self):
        from .events import event_summary
        if self.account_role()['role'] == 'guardian':
            self.verified_email()
        return event_summary(active_event(self.db))

    def profile(self):
        doc = self.user.get()
        if not doc.exists:
            raise HTTPException(404, detail="profile_missing")
        data = doc.to_dict()
        assert_guardian_role(self.token, data)
        self.verified_email()
        if not data.get("full_name") or not data.get("phone"):
            raise HTTPException(404, detail="profile_incomplete")
        return {"full_name": data["full_name"], "phone": data["phone"], "email": self.token.get("email", ""), "role": "guardian"}

    def account_verification(self):
        self.profile()
        event = active_event(self.db)
        nonce = secrets.token_urlsafe(32)
        digest = hashlib.sha256(nonce.encode()).hexdigest()
        expires = datetime.now(timezone.utc) + timedelta(minutes=5)
        ref = self.user.collection("verification").document("current")
        @firestore.transactional
        def issue(tx):
            tx.set(ref, {"token_hash": digest, "guardian_id": self.uid,
                "event_id": event.id, "expires_at": expires, "consumed_at": None})
        issue(self.db.transaction())
        return {"payload": "radd:guardian-verification:v1:" + self.uid + ":" + nonce,
            "expires_at": expires}

    def register_fcm_token(self, token, locale="en"):
        self.profile()
        doc_id = hashlib.sha256(token.encode()).hexdigest()
        for other in self.db.collection("users").stream():
            if other.id == self.uid:
                continue
            stale = other.reference.collection("fcm_registrations").document(doc_id).get()
            if stale.exists and stale.to_dict().get("token") == token:
                stale.reference.delete()
        ref = self.user.collection("fcm_registrations").document(doc_id)
        @firestore.transactional
        def upsert(tx):
            existing = ref.get(transaction=tx)
            data = {"token": token, "locale": locale, "updated_at": firestore.SERVER_TIMESTAMP,
                "session_expires_at": self.token.get("exp", 0), "session_auth_time": self.token.get("auth_time", 0)}
            if not existing.exists:
                data["created_at"] = firestore.SERVER_TIMESTAMP
            tx.set(ref, data, merge=True)
        upsert(self.db.transaction())
        return {"registered": True}

    def unregister_fcm_token(self, token):
        self.profile()
        doc_id = hashlib.sha256(token.encode()).hexdigest()
        self.user.collection("fcm_registrations").document(doc_id).delete()
        return {"unregistered": True}

    def save_profile(self, value, create=False):
        if self.token.get("role") not in (None, "guardian"):
            raise HTTPException(403, detail="guardian_required")
        transaction = self.db.transaction()
        @firestore.transactional
        def save(tx):
            doc = self.user.get(transaction=tx)
            if doc.exists:
                assert_guardian_role(self.token, doc.to_dict())
            elif not create:
                raise HTTPException(404, detail="profile_missing")
            self.verified_email()
            if create and doc.exists and doc.to_dict().get("full_name") and doc.to_dict().get("phone"):
                return
            data = {"full_name": value.full_name, "phone": value.phone, "role": "guardian", "updated_at": firestore.SERVER_TIMESTAMP}
            if not doc.exists:
                data.update(created_at=firestore.SERVER_TIMESTAMP, age_confirmed_at=firestore.SERVER_TIMESTAMP, privacy_acknowledged_at=firestore.SERVER_TIMESTAMP, privacy_notice_version="sprint0-interim-1")
            tx.set(self.user, data, merge=True)
        save(transaction)
        return self.profile()

    def collection(self):
        self.profile()
        return self.user.collection("individuals")

    def get(self, item_id, include_deleting=False):
        doc = self.collection().document(item_id).get()
        data = owned_registration(doc.to_dict(), self.uid)
        if data.get("deleting") and not include_deleting:
            raise HTTPException(404, detail="not_found")
        return doc

    def list(self):
        return [public_individual(d, self.db) for d in self.collection().stream() if not d.to_dict().get("deleting")]

    def photo(self, item_id):
        doc = self.get(item_id)
        data = doc.to_dict()
        if not data.get("photo_path") or photo_expired(data, self.db, case_context=True):
            raise HTTPException(404, detail="photo_expired")
        return bucket().blob(data["photo_path"]).download_as_bytes()

    def cleanup(self, path):
        if not path:
            return
        try:
            blob = bucket().blob(path)
            if blob.exists():
                blob.delete()
        except Exception:
            self.db.collection("photo_cleanup").add({"path": path, "created_at": firestore.SERVER_TIMESTAMP})

    def save(self, value, item_id=None):
        collection = self.collection()
        existing = self.get(item_id) if item_id else None
        if existing is None and not value.photo_base64:
            raise HTTPException(422, detail="photo_required")
        if existing is not None:
            ensure_deletable(existing.to_dict())
        ref = collection.document(item_id) if item_id else collection.document()
        new_path = None
        if value.photo_base64:
            content = normalize_photo(value.photo_base64)
            embedding = firestore.DELETE_FIELD
            try:
                engine = face_matching.get_engine()
                if engine is not None:
                    embedding = engine.embed(content)
            except face_matching.Unavailable:
                raise HTTPException(503, detail="face_matching_unavailable") from None
            new_path = "guardians/" + self.uid + "/individuals/" + ref.id + "/" + uuid4().hex + ".jpg"
            bucket().blob(new_path).upload_from_string(content, content_type="image/jpeg")
        transaction = self.db.transaction()
        @firestore.transactional
        def save(tx):
            current = ref.get(transaction=tx)
            if existing:
                current_data = owned_registration(current.to_dict(), self.uid)
                if current_data.get("deleting"):
                    raise HTTPException(409, detail="deletion_in_progress")
                ensure_deletable(current_data)
            else:
                current_data = {}
            event = active_event(self.db, tx) if existing is None or value.registration_period_id is not None else None
            if existing and not registration_available(current_data, self.db, tx):
                raise HTTPException(409, detail='registration_unavailable')
            data = value.model_dump(exclude={"photo_base64", "registration_period_id"})
            if existing and value.registration_period_id is not None:
                if current_data.get("event_id") != event.id:
                    raise HTTPException(409, detail='registration_unavailable')
                if value.registration_period_id != current_data.get("registration_period_id"):
                    data.update(reschedule(event, current_data, value.registration_period_id))
            data.update(guardian_id=self.uid, updated_at=firestore.SERVER_TIMESTAMP)
            if new_path:
                data["photo_path"] = new_path
                data[face_matching.EMBEDDING_FIELD] = embedding
                for legacy in face_matching.LEGACY_EMBEDDING_FIELDS:
                    data[legacy] = firestore.DELETE_FIELD
                data["embedding_path"] = firestore.DELETE_FIELD
                data["photo_captured_at"] = firestore.SERVER_TIMESTAMP
            if existing is None:
                data["created_at"] = firestore.SERVER_TIMESTAMP
                data["event_id"] = event.id
                data.update(establish(event, value.registration_period_id))
            tx.set(ref, data, merge=True)
            return (current_data.get("photo_path"), current_data.get("embedding_path"))
        try:
            old_path, old_embedding = save(transaction)
        except Exception:
            self.cleanup(new_path)
            raise
        if new_path and old_path:
            self.cleanup(old_path)
        if new_path and old_embedding:
            self.cleanup(old_embedding)
        return public_individual(ref.get(), self.db)

    def retention_options(self, item_id):
        data = self.get(item_id).to_dict()
        event = active_event(self.db)
        if data.get("event_id") != event.id or not registration_available(data, self.db):
            raise HTTPException(409, detail='registration_unavailable')
        return {"individual_id": item_id, "event_id": event.id,
                "event_ends_at": event.to_dict().get("ends_at"),
                "started_at": data.get("registration_started_at"),
                "expires_at": data.get("registration_expires_at"),
                "current_period_id": data.get("registration_period_id"),
                "editable": not (data.get("active_case_id") or data.get("active_found_report_id")),
                "options": edit_options(event, data)}

    def delete(self, item_id):
        doc = self.get(item_id, include_deleting=True)
        transaction = self.db.transaction()
        @firestore.transactional
        def mark(tx):
            current = doc.reference.get(transaction=tx)
            data = owned_registration(current.to_dict(), self.uid)
            ensure_deletable(data)
            tx.update(doc.reference, {"deleting": True})
            return [data.get("photo_path"), data.get("embedding_path")]
        paths = mark(transaction)
        for path in paths:
            if path:
                self.cleanup(path)
        doc.reference.delete()
