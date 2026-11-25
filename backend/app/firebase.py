import os
import time
from functools import lru_cache
import firebase_admin
from firebase_admin import auth, firestore, storage
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

@lru_cache
def firebase_app():
    return firebase_admin.initialize_app(options={
        "projectId": os.getenv("FIREBASE_PROJECT_ID", "radd-32eb6"),
        "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", "radd-32eb6.firebasestorage.app"),
        "httpTimeout": 5,
    }, name="radd-backend")

def database():
    return firestore.client(app=firebase_app())

def bucket():
    return storage.bucket(app=firebase_app())

bearer = HTTPBearer(auto_error=False)

def require_verified_email(token):
    if token.get('email_verified') is not True or not token.get('email'):
        raise HTTPException(403, detail='email_verification_required')
    try:
        user = auth.get_user(token['uid'], app=firebase_app())
    except auth.UserNotFoundError:
        raise HTTPException(401, detail='unauthorized') from None
    except Exception:
        raise HTTPException(503, detail='service_unavailable') from None
    if user.disabled:
        raise HTTPException(401, detail='account_disabled')
    if (user.email_verified is not True or not user.email or
            user.email.casefold() != token['email'].casefold()):
        raise HTTPException(403, detail='email_verification_required')

def identity(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if credentials is None:
        raise HTTPException(401, detail="unauthorized")
    attempts = 3
    started = time.monotonic()
    for attempt in range(attempts):
        try:
            return auth.verify_id_token(credentials.credentials, app=firebase_app(), check_revoked=True, clock_skew_seconds=10)
        except auth.UserDisabledError:
            raise HTTPException(401, detail="account_disabled") from None
        except (auth.InvalidIdTokenError, auth.ExpiredIdTokenError, auth.RevokedIdTokenError, ValueError):
            raise HTTPException(401, detail="unauthorized") from None
        except Exception:
            if attempt == attempts - 1 or time.monotonic() - started >= 8:
                raise HTTPException(503, detail="service_unavailable") from None
            time.sleep(0.3 * (attempt + 1))
