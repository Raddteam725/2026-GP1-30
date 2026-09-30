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
from .firebase import database, bucket
from .events import active_event

Image.MAX_IMAGE_PIXELS = 20_000_000

def assert_guardian_role(token, profile):
    if token.get("role") not in (None, "guardian") or profile.get("role") != "guardian":
        raise HTTPException(403, detail="guardian_required")
    # Admin-managed account status: a deactivated Guardian cannot use any
    # authenticated function (every Guardian operation passes through here
    # via profile()). Absent means enabled; only an explicit False deactivates.
    if profile.get("active") is False:
        raise HTTPException(403, detail="account_inactive")

def owned_registration(data, uid):
    if not data or data.get("guardian_id") != uid:
        raise HTTPException(404, detail="not_found")
    return data

def ensure_deletable(data):
    # Also used to guard edits: an active case's reference profile/photo must not
    # change under it, so this rejects both delete and edit while active_case_id
    # is set. Case creation/cancellation must update this field in the same
    # transaction as the case's own status change.
    if data.get("active_case_id") or data.get("active_found_report_id"):
        raise HTTPException(409, detail="active_case")

from .registration_retention import registration_available, establish, reschedule, edit_options


def photo_expired(data, db=None, tx=None, *, case_context=False):
    # Compatibility API name: now registration validity, never photograph age.
    return not registration_available(data, db, tx, case_context=case_context)

def public_individual(doc, db=None):
    data = doc.to_dict()
    return {**{k: data[k] for k in ("full_name", "age", "gender", "relationship")},
        "relationship_other": data.get("relationship_other"),
        "id": doc.id, "active_case_id": data.get("active_case_id"),
        # The retention the Guardian chose: shown on the profile and editable
        # there (see GuardianService.retention_options / save).
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
        # Volunteer role/status now come from the admin-owned users document.
        # VolunteerService.profile() authoritatively denies inactive accounts;
        # resolving a role alone never grants access to protected data or ID.
        doc = self.user.get()
        if not doc.exists:
            raise HTTPException(404, detail="profile_missing")
        role = doc.to_dict().get("role")
        # Admin accounts use the web Admin Portal (app.admin), never the mobile
        # roles; resolving one here is a role mismatch, not a mobile session.
        if role not in ("guardian", "volunteer") or self.token.get("role") not in (None, role):
            raise HTTPException(403, detail="role_unresolved")
        return {"role": role}

    def current_event(self):
        """The one Active event, for any resolvable mobile role (Guardian or
        Volunteer): the same authoritative record Admin manages. Fails closed
        (503 event_unavailable) when no event is Active -- never a placeholder."""
        from .events import event_summary
        self.account_role()
        return event_summary(active_event(self.db))

    def profile(self):
        doc = self.user.get()
        if not doc.exists:
            raise HTTPException(404, detail="profile_missing")
        data = doc.to_dict()
        assert_guardian_role(self.token, data)
        if not data.get("full_name") or not data.get("phone"):
            raise HTTPException(404, detail="profile_incomplete")
        return {"full_name": data["full_name"], "phone": data["phone"], "email": self.token.get("email", ""), "role": "guardian"}

    def account_verification(self):
        # One Guardian-account-level QR, not one per case: the Volunteer's own
        # current case supplies case context (see VolunteerWorkflow.verify_guardian).
        # Opaque, short-lived, single-use bearer challenge. No password/Admin-key/
        # unnecessary PII in the payload -- only this account's UID and a random nonce.
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
        # A Guardian-owned SUBcollection, not an array field on the account
        # doc: each app installation gets its own document, so one can be
        # removed (see app.push.notify_guardian's UnregisteredError handling)
        # or refreshed without touching any other installation's registration.
        # The doc ID is derived from the token itself (never client-supplied)
        # so re-uploading the SAME token is inherently idempotent -- it always
        # resolves to the same document instead of accumulating duplicates.
        # `locale` is this installation's own current in-app language (never
        # the device's system locale) -- only ever "en"/"ar" (Radd's own
        # supported languages), used solely to pick which of two fixed,
        # generic, pre-translated strings the visible notification uses.
        self.profile()
        doc_id = hashlib.sha256(token.encode()).hexdigest()
        # Defense-in-depth against a cross-account leak if a PREVIOUS
        # logout's best-effort cleanup never reached the server (e.g. this
        # device was offline at logout time, or the app was killed without a
        # clean sign-out): this same installation registering again -- which
        # must happen for ANY guardian to receive pushes on it -- sweeps away
        # any OTHER guardian's registration for this exact token first, so a
        # token is never simultaneously live under two guardians. A second
        # legitimate device (a different token) is never touched by this.
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
        # Always scoped to the CALLER's own subcollection (self.user) -- there
        # is no way to target another guardian's registration through this or
        # any other endpoint. Deleting an already-absent document is a no-op,
        # so this is safe to call repeatedly (e.g. a retried logout).
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
        return [public_individual(d, self.db) for d in self.collection().stream() if not d.to_dict().get("deleting")]

    def photo(self, item_id):
        doc = self.get(item_id)
        data = doc.to_dict()
        # Registration validity, including an authorized active-case deferral.
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
            # Durable cleanup record; never silently abandon a replaced photo.
            self.db.collection("photo_cleanup").add({"path": path, "created_at": firestore.SERVER_TIMESTAMP})

    def save(self, value, item_id=None):
        collection = self.collection()
        existing = self.get(item_id) if item_id else None
        if existing is None and not value.photo_base64:
            raise HTTPException(422, detail="photo_required")
        if existing is not None:
            # The reference profile/photo an active case already distributed to the
            # search workflow must not change under it. Checked again inside the
            # transaction below against a concurrent case creation.
            ensure_deletable(existing.to_dict())
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
                ensure_deletable(current_data)
            else:
                current_data = {}
            event = active_event(self.db, tx) if existing is None or value.registration_period_id is not None else None
            if existing and not registration_available(current_data, self.db, tx):
                raise HTTPException(409, detail='registration_unavailable')
            data = value.model_dump(exclude={"photo_base64", "registration_period_id"})
            if existing and value.registration_period_id is not None:
                # Retention change from the profile: the start never moves,
                # the new deadline must be in the future and within the event.
                if current_data.get("event_id") != event.id:
                    raise HTTPException(409, detail='registration_unavailable')
                if value.registration_period_id != current_data.get("registration_period_id"):
                    data.update(reschedule(event, current_data, value.registration_period_id))
            data.update(guardian_id=self.uid, updated_at=firestore.SERVER_TIMESTAMP)
            if new_path:
                data["photo_path"] = new_path
                # Capture metadata is not a retention deadline. Invalidate the
                # old reference embedding when replacing the photograph.
                data["face_embedding"] = firestore.DELETE_FIELD
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
        """What the Guardian may change this registration's retention to."""
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
