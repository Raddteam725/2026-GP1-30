import base64
import binascii
import io
import os
from uuid import uuid4
from PIL import Image, ImageOps, UnidentifiedImageError
from fastapi import HTTPException
from firebase_admin import firestore
from .firebase import database, bucket

Image.MAX_IMAGE_PIXELS = 20_000_000

def assert_guardian_role(token, profile):
    if token.get("role") not in (None, "guardian") or profile.get("role") != "guardian":
        raise HTTPException(403, detail="guardian_required")

def owned_registration(data, uid):
    if not data or data.get("guardian_id") != uid:
        raise HTTPException(404, detail="not_found")
    return data

def ensure_deletable(data):
    # Future case transitions must update this field in the same transaction
    # and refuse to attach a case to a deleting registration.
    if data.get("active_case_id"):
        raise HTTPException(409, detail="active_case")

def public_individual(doc):
    data = doc.to_dict()
    return {**{k: data[k] for k in ("full_name", "age", "gender", "relationship")}, "id": doc.id}

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
            return output.getvalue()  # No EXIF/location metadata retained.
    except (ValueError, binascii.Error, UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise HTTPException(422, detail="invalid_photo") from None

class GuardianService:
    def __init__(self, token):
        self.token = token
        self.uid = token["uid"]
        self.db = database()
        self.user = self.db.collection("users").document(self.uid)

    def account_role(self):
        # Match the existing Volunteer team contract; never assign a role from client input.
        if self.token.get("role") == "volunteer":
            if self.token.get("enabled") is True and isinstance(self.token.get("volunteerId"), str) and self.token["volunteerId"].strip():
                return {"role": "volunteer"}
            raise HTTPException(403, detail="volunteer_disabled")
        doc = self.user.get()
        if not doc.exists:
            raise HTTPException(404, detail="profile_missing")
        role = doc.to_dict().get("role")
        if role not in ("guardian", "volunteer") or self.token.get("role") not in (None, role):
            raise HTTPException(403, detail="role_unresolved")
        return {"role": role}

    def profile(self):
        doc = self.user.get()
        if not doc.exists:
            raise HTTPException(404, detail="profile_missing")
        data = doc.to_dict()
        assert_guardian_role(self.token, data)
        if not data.get("full_name") or not data.get("phone"):
            raise HTTPException(404, detail="profile_incomplete")
        return {"full_name": data["full_name"], "phone": data["phone"], "email": self.token.get("email", ""), "role": "guardian"}

    def save_profile(self, value, create=False):
        if self.token.get("role") not in (None, "guardian"):
            raise HTTPException(403, detail="guardian_required")
        transaction = self.db.transaction()
        @firestore.transactional
        def save(tx):
            doc = self.user.get(transaction=tx)
            if doc.exists:
                assert_guardian_role(self.token, doc.to_dict())
                if create and doc.to_dict().get("full_name") and doc.to_dict().get("phone"):
                    return  # Idempotent recovery after a lost creation response.
            elif not create:
                raise HTTPException(404, detail="profile_missing")
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
        return [public_individual(d) for d in self.collection().stream() if not d.to_dict().get("deleting")]

    def photo(self, item_id):
        doc = self.get(item_id)
        return bucket().blob(doc.to_dict()["photo_path"]).download_as_bytes()

    def cleanup(self, path):
        if not path:
            return
        try:
            blob = bucket().blob(path)
            if blob.exists():
                blob.delete()
        except Exception:
            # Durable cleanup record; never silently abandon a replaced photo.
            self.db.collection("photo_cleanup").add({"path": path, "created_at": firestore.SERVER_TIMESTAMP})

    def save(self, value, item_id=None):
        collection = self.collection()
        existing = self.get(item_id) if item_id else None
        if existing is None and not value.photo_base64:
            raise HTTPException(422, detail="photo_required")
        ref = collection.document(item_id) if item_id else collection.document()
        new_path = None
        if value.photo_base64:
            content = normalize_photo(value.photo_base64)
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
            else:
                current_data = {}
            data = value.model_dump(exclude={"photo_base64"})
            data.update(guardian_id=self.uid, updated_at=firestore.SERVER_TIMESTAMP)
            if new_path:
                data["photo_path"] = new_path
            if existing is None:
                data["created_at"] = firestore.SERVER_TIMESTAMP
                event = os.getenv("RADD_ACTIVE_EVENT_ID")
                if event:
                    data["event_id"] = event
            tx.set(ref, data, merge=True)
            return current_data.get("photo_path")
        try:
            old_path = save(transaction)
        except Exception:
            self.cleanup(new_path)
            raise
        if new_path and old_path:
            self.cleanup(old_path)
        return public_individual(ref.get())

    def delete(self, item_id):
        doc = self.get(item_id, include_deleting=True)
        transaction = self.db.transaction()
        @firestore.transactional
        def mark(tx):
            current = doc.reference.get(transaction=tx)
            data = owned_registration(current.to_dict(), self.uid)
            ensure_deletable(data)
            tx.update(doc.reference, {"deleting": True})
            return data["photo_path"]
        path = mark(transaction)
        self.cleanup(path)
        doc.reference.delete()
