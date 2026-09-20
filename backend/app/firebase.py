import os
import time
from functools import lru_cache
import firebase_admin
from firebase_admin import auth, firestore, storage
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

@lru_cache
def firebase_app():
    # Application Default Credentials; never load keys from the repository.
    return firebase_admin.initialize_app(options={
        "projectId": os.getenv("FIREBASE_PROJECT_ID", "radd-32eb6"),
        "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", "radd-32eb6.firebasestorage.app"),
    }, name="radd-backend")

def database():
    return firestore.client(app=firebase_app())

def bucket():
    return storage.bucket(app=firebase_app())

bearer = HTTPBearer(auto_error=False)
def identity(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if credentials is None:
        raise HTTPException(401, detail="unauthorized")
    # check_revoked=True makes a network round-trip on every request (beyond
    # local JWT verification); a transient connection blip there must not
    # surface as "unavailable" to the Guardian on an otherwise-healthy token.
    attempts = 3
    for attempt in range(attempts):
        try:
            return auth.verify_id_token(credentials.credentials, app=firebase_app(), check_revoked=True)
        except auth.UserDisabledError:
            raise HTTPException(401, detail="account_disabled") from None
        except (auth.InvalidIdTokenError, auth.ExpiredIdTokenError, auth.RevokedIdTokenError, ValueError):
            raise HTTPException(401, detail="unauthorized") from None
        except Exception:
            if attempt == attempts - 1:
                raise HTTPException(503, detail="service_unavailable") from None
            time.sleep(0.3 * (attempt + 1))
