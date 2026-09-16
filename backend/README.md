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
All /v1 endpoints require a verified, non-revoked Firebase ID token. Identity comes from the token, never a submitted Guardian ID. Revocation checking makes one network round-trip per request; a token that is actually invalid/expired/revoked returns 401 immediately, but a transient connection failure on that round-trip is retried (3 attempts, short backoff) before giving up with 503 — a single dropped connection must not surface as "service unavailable" for an otherwise-healthy Guardian action.
GET /v1/session resolves the authenticated server-owned mobile role before any Guardian profile request. Missing profiles return 404; unknown or conflicting roles return 403.
PUT/GET/PATCH /v1/guardian creates, reads and safely updates a Guardian profile. Email comes from the verified token; it is not editable here.
POST/GET /v1/individuals; GET/PUT/DELETE /v1/individuals/{id}; GET /v1/individuals/{id}/photo.
Profile creation records the two acknowledgements. Auth users without a profile can retry completion after an interrupted account creation.
Individual JSON uses full_name, age, gender, relationship (`child`|`parent`|`other`), relationship_other (required only when relationship is `other`; rejected otherwise) and optional photo_base64 (required on create). Photographs are normalized to JPEG with metadata removed. Camera-only acquisition is enforced by the app UI; the server cannot prove image provenance from bytes alone.
While an individual has an active_case_id, PUT (edit) and DELETE both fail closed with 409 `active_case` — enforced in `service.save`/`delete`, not just the Flutter buttons being disabled. The lock clears automatically (same transaction) when that case reaches any terminal status, and Report Missing on that individual becomes available again.
POST/GET /v1/cases; GET /v1/cases/{id}; PUT /v1/cases/{id}/guided-report; POST /v1/cases/{id}/cancel; POST /v1/cases/{id}/resolve; POST /v1/cases/{id}/verification. GET/PUT /v1/notifications. A Guardian may hold at most one active case per individual; creating a second while one is active is idempotent and returns the existing one — once terminal, reporting again always creates a genuinely new case (never reuses or overwrites the old id). Guardian-side terminal outcomes are `cancelled` (mistaken report) and `resolved` (Guardian found the individual independently) via the two endpoints above; `reunited` and `transferred_to_authority` are Volunteer/Admin-only transitions, not reachable from this API. Guardians otherwise cannot set case status directly — sequential progression (`report_received` → … → `awaiting_guardian_verification` → `reunited`) belongs to Volunteer/Admin services with role and verification checks. A closed case is never deleted: `status` becomes terminal, `closed_at` is stamped, and the document remains in `cases/` for history/Admin reporting; only `active_case_id` on the individual is cleared. Guided-report answers become read-only once `completed: true` (409 `report_already_submitted` on further writes) — not a permanent editable chat session. Issuing a QR verification payload never changes status and carries no UID or PII, only an opaque nonce tied server-side to the case and Guardian; it is only issued once a case reaches `awaiting_guardian_verification`.

## Data
users/{uid}: role, full_name, phone, server timestamps and acknowledgement version.
users/{uid}/individuals/{id}: ownership, demographic fields, relationship_other, private photo_path, timestamps, event_id, active_case_id (null once any case on this individual is terminal).
users/{uid}/notifications/{id}: case_id, kind (`case_created`|`status_changed`), status, timestamps, read_at.
cases/{id}: shared top-level collection — the SAME canonical record Guardian, Volunteer and Admin services all read/write; never duplicated per role. guardian_id, individual_id, individual_name/age snapshot, age_group (bucketed, for Admin statistics without retaining exact age on old cases), event_id, status, stage_timestamps (the 5-stage reunification path only), guided_report, created_at, updated_at, closed_at (null while active; stamped once terminal — the retained closure timestamp for reporting).
cases/{id}/verification/current: token_hash, expires_at, consumed_at — never the raw nonce.
alerts/{id}: shared top-level collection, the canonical Guardian→Volunteer alert intent (not a Guardian-only or Volunteer-only store). Written once per successful case creation: case_id, event_id, kind (`general` now; `priority` shape reserved for a future proximity worker), status, recipient_volunteer_id, proximity_eligible, distance_meters, delivered (always `False` here — no Volunteer device-token/location integration exists yet in this codebase, so this never claims a delivery that did not happen), created_at. `alerts.PROXIMITY_RADIUS_METERS` (500m) is the one centralized constant a future proximity worker should read.
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
