"""FCM registration eligibility tied to the account's real Firebase session.

Shared by both roles (app.push for Guardians, app.volunteer_alerts for
Volunteers). A registration is stamped at upload time with the verified ID
token's own `exp` and `auth_time` claims (see service.register_fcm_token).
While `session_expires_at` is in the future the registration is trusted
as-is. Once it has passed, the registration is NOT silently dropped -- a
Firebase ID token only lives one hour, and its expiry says nothing about
whether the person is still signed in. Instead the account's session is
re-checked against Firebase Auth itself (`auth.get_user`): a disabled
account, or one whose refresh tokens were revoked after this registration's
sign-in (`tokens_valid_after_timestamp` > `auth_time`), ends delivery and
removes the registration; a still-valid session is trusted for one more
token lifetime and re-checked again after that. Expiry checks therefore
always remain, nothing is valid forever without Firebase confirming it, and
the extension is never arbitrary -- it is exactly Firebase's own ID-token
lifetime, granted only after Firebase confirmed the session.

Logout / account switch still remove the registration outright (see
service.unregister_fcm_token and the re-registration sweep); an inactive
Volunteer is excluded before this module is even consulted.
"""
import logging
from datetime import datetime, timedelta, timezone
from firebase_admin import auth, firestore
from .firebase import firebase_app

# Firebase's ID-token lifetime: how long a confirmed session is trusted
# before it is confirmed against Firebase Auth again.
SESSION_WINDOW = timedelta(hours=1)

def stamp(token):
    """Session fields recorded on a registration from the VERIFIED token."""
    now = datetime.now(timezone.utc).timestamp()
    exp = token.get("exp")
    return {
        "session_expires_at": exp if isinstance(exp, (int, float)) else now + SESSION_WINDOW.total_seconds(),
        "auth_time": token.get("auth_time") if isinstance(token.get("auth_time"), (int, float)) else now,
    }

def verify_session(uid, registration):
    """'valid' | 'revoked' | 'unknown' -- asks Firebase Auth, never the client."""
    try:
        user = auth.get_user(uid, app=firebase_app())
    except auth.UserNotFoundError:
        return "revoked"
    except Exception as error:
        logging.getLogger(__name__).warning("Session check unavailable (%s)", type(error).__name__)
        return "unknown"
    if user.disabled:
        return "revoked"
    valid_after = (user.tokens_valid_after_timestamp or 0) / 1000
    auth_time = registration.get("auth_time")
    if not isinstance(auth_time, (int, float)):
        # Registration predates session stamping: its sign-in can only be
        # dated to (at the latest) one token lifetime before its expiry.
        auth_time = (registration.get("session_expires_at") or 0) - SESSION_WINDOW.total_seconds()
    return "revoked" if valid_after > auth_time else "valid"

def eligible_registrations(user_ref, uid, *, event_id=None):
    """Registrations of one account that may receive its role's pushes now.

    A registration whose trusted window has passed is re-confirmed with
    Firebase (see module docstring) and extended on success; a revoked or
    disabled session deletes it; a transient Firebase failure skips it for
    this attempt only (the durable notification stays retryable).
    """
    now = datetime.now(timezone.utc)
    result = []
    for registration in user_ref.collection("fcm_registrations").stream():
        data = registration.to_dict() or {}
        if not data.get("token"):
            continue
        if event_id is not None and data.get("event_id") != event_id:
            continue
        if (data.get("session_expires_at") or 0) > now.timestamp():
            result.append(registration)
            continue
        state = verify_session(uid, data)
        if state == "revoked":
            registration.reference.delete()
            continue
        if state != "valid":
            continue
        registration.reference.update({
            "session_expires_at": (now + SESSION_WINDOW).timestamp(),
            "session_verified_at": firestore.SERVER_TIMESTAMP,
        })
        result.append(registration)
    return result
