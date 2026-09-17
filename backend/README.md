# Radd shared API
Flutter stays at the repository root. This is the shared FastAPI business layer for the Radd team. See ../TEAM_SETUP.md for secure local startup.

## Local startup
Use Python 3.11+ in a project-local virtual environment:
```powershell
py -m venv backend/.venv
backend/.venv/Scripts/python -m pip install -r backend/requirements.txt
backend/.venv/Scripts/python -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000
```
Supply Application Default Credentials to that process (for example GOOGLE_APPLICATION_CREDENTIALS pointing to a protected service-account file OUTSIDE the repository). Do not commit credentials. Defaults reuse radd-32eb6 and radd-32eb6.firebasestorage.app. FIREBASE_PROJECT_ID and FIREBASE_STORAGE_BUCKET are process configuration. Do not point this service at another project.

Registering an individual or reporting a case requires exactly one `events` document with `active: true`; there is no per-request event selection. For local development, run `run_dev.py --bootstrap-event` once to create it (idempotent; refuses to run if more than one active event already exists).

Android emulator debug builds use http://10.0.2.2:8000. Release builds require an HTTPS RADD_API_URL via --dart-define. Only debug Android configuration permits local cleartext traffic.

Firebase Email/Password must be enabled. Firestore and Storage must exist in the configured project, with appropriate server IAM access. Admin SDK bypasses client rules. Mobile clients access structured data and private photos through this API, never public download URLs. Do not deploy global rules that affect the other team's features; restrict these new users/{uid}/individuals and guardians/... photo namespaces from direct client writes/reads in the project's rules review.

## Contract
All /v1 endpoints require a verified, non-revoked Firebase ID token. Identity comes from the token, never a submitted Guardian ID.
GET /v1/session resolves the authenticated server-owned mobile role before any Guardian profile request. Missing profiles return 404; unknown or conflicting roles return 403.
PUT/GET/PATCH /v1/guardian creates, reads and safely updates a Guardian profile. Email comes from the verified token; it is not editable here.
POST/GET /v1/individuals; GET/PUT/DELETE /v1/individuals/{id}; GET /v1/individuals/{id}/photo.
Profile creation records the two acknowledgements. Auth users without a profile can retry completion after an interrupted account creation.
Individual JSON uses full_name, age, gender, relationship and optional photo_base64 (required on create). Photographs are normalized to JPEG with metadata removed. Camera-only acquisition is enforced by the app UI; the server cannot prove image provenance from bytes alone.
POST/GET /v1/cases; GET /v1/cases/{id}; PUT /v1/cases/{id}/guided-report; POST /v1/cases/{id}/verification. GET/PUT /v1/notifications. A Guardian may hold at most one active (non-`reunited`) case per individual; creating a second is idempotent and returns the existing one. Guardians cannot set case status directly — that transition belongs to Volunteer/Admin services with role and verification checks; this API only ever advances a case from `report_received` through guided-report data entry, and issues a short-lived, revocable QR verification payload once a case reaches `awaiting_guardian_verification`. The QR payload carries no UID or PII — only an opaque nonce tied server-side to the case and Guardian.

## Data
users/{uid}: role, full_name, phone, server timestamps and acknowledgement version.
users/{uid}/individuals/{id}: ownership, demographic fields, private photo_path, timestamps, event_id, active_case_id.
users/{uid}/notifications/{id}: case_id, kind, status, timestamps, read_at.
cases/{id}: shared top-level collection (Guardian-scoped here; Volunteer/Admin services read the same records), guardian_id, individual_id, event_id, status, stage_timestamps, guided_report.
cases/{id}/verification/current: token_hash, expires_at, consumed_at — never the raw nonce.
events/{id}: name, active, environment. Exactly one may have `active: true`; requests fail closed (503) if zero or more than one do.
Storage: guardians/{uid}/individuals/{id}/{random}.jpg.
No seed data. A new account lists zero individuals and zero cases.
Deletion transaction rejects active_case_id and marks deleting before photo cleanup; case creation transactionally refuses deleting records.
Failed photo removal creates photo_cleanup records; run the cleanup command with the same server credentials before operational deployment and schedule it regularly. A deletion interrupted after marking can be retried with the same ID.
Auth registration and Firestore are separate services: account creation failures after Firebase signup retain the authenticated session so profile completion can be retried.

## Tests
```powershell
backend/.venv/Scripts/python -m pytest backend/tests
```
Unit/API tests use isolated fakes only; they do not seed production.
