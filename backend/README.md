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
POST/GET /v1/cases; GET /v1/cases/{id}; PUT /v1/cases/{id}/guided-report; POST /v1/cases/{id}/cancel; POST /v1/cases/{id}/resolve; POST /v1/guardian/verification. GET/PUT /v1/notifications. A Guardian may hold at most one active case per individual; creating a second while one is active is idempotent and returns the existing one — once terminal, reporting again always creates a genuinely new case (never reuses or overwrites the old id). Reporting also fails closed (409 `photo_expired`) if the individual's registration retention is unavailable — see Retention below; this is enforced here, not only by the Flutter UI's own prompt. Guardian-side terminal outcomes are `cancelled` (mistaken report) and `resolved` (Guardian found the individual independently) via the two endpoints above; `reunited` and `transferred_to_authority` are Volunteer/Admin-only transitions, not reachable from this API. Guardians otherwise cannot set case status directly — sequential progression (`report_received` → … → `awaiting_guardian_verification` → `reunited`) belongs to Volunteer/Admin services with role and verification checks. A closed case is retained (never deleted outright) until the retention job scrubs it 24h after `closed_at` — see Retention below. Guided-report answers become read-only once `completed: true` (409 `report_already_submitted` on further writes) — not a permanent editable chat session. `POST /v1/guardian/verification` issues an account-level QR payload (never per-case): an opaque nonce tied server-side to the Guardian's UID, consumed by whichever case a Volunteer is currently confirming (`VolunteerWorkflow.verify_guardian`) — it carries no case ID, password, or PII.
`PUT /v1/guardian/fcm-registrations` registers/refreshes this installation's FCM registration for the authenticated Guardian; `POST /v1/guardian/fcm-registrations/unregister` removes it (called at logout). See Push below for the schema and full contract.

## Data
users/{uid}: role, full_name, phone, server timestamps and acknowledgement version.
users/{uid}/individuals/{id}: ownership, demographic fields, relationship_other, private photo_path, timestamps, event_id, active_case_id (null once any case on this individual is terminal).
users/{uid}/notifications/{id}: case_id, kind (`case_created`|`status_changed`), status, timestamps, read_at.
cases/{id}: shared top-level collection — the SAME canonical record Guardian, Volunteer and Admin services all read/write; never duplicated per role. Before retention scrubs it (see below): guardian_id, individual_id, individual_name/age snapshot, age_group (bucketed, for Admin statistics without retaining exact age), event_id, status, stage_timestamps (the 5-stage reunification path only), guided_report, guardian_verification, confirmed_by/found_report_id/joined_by/handed_over_by/handed_over_at, created_at, updated_at, closed_at (null while active; stamped once terminal).
users/{uid}/verification/current: token_hash, guardian_id, event_id, expires_at, consumed_at — account-level (one per Guardian, not per case), never the raw nonce.
users/{uid}/fcm_registrations/{sha256(token)}: token, locale, created_at, updated_at — one document per app installation (never a single array field), so any one can be refreshed or removed independently. The doc id is derived from the token itself, making re-registration inherently idempotent. See Push below.
alerts/{id}: shared top-level collection, the canonical Guardian→Volunteer alert intent (not a Guardian-only or Volunteer-only store). Written once per successful case creation: case_id, event_id, kind (`general` now; `priority` shape reserved for a future proximity worker), status, recipient_volunteer_id, proximity_eligible, distance_meters, delivered (always `False` here — no Volunteer device-token/location integration exists yet in this codebase, so this never claims a delivery that did not happen), created_at. `alerts.PROXIMITY_RADIUS_METERS` (500m) is the one centralized constant a future proximity worker should read.
events/{id}: name, active, environment. Exactly one may have `active: true`; requests fail closed (503) if zero or more than one do.
Storage: guardians/{uid}/individuals/{id}/{random}.jpg.
No seed data. A new account lists zero individuals and zero cases.
Deletion transaction rejects active_case_id and marks deleting before photo cleanup; case creation transactionally refuses deleting records.
Failed photo removal (from a replaced/interrupted save) creates photo_cleanup records; the cleanup command below drains that queue. A deletion interrupted after marking can be retried with the same ID.
Auth registration and Firestore are separate services: account creation failures after Firebase signup retain the authenticated session so profile completion can be retried.

## Retention
Registered photographs and face embeddings follow the registration's explicit
`registration_expires_at`, established from the current Active Event's configured
period options. Photo age is not an eligibility rule. Photo replacement and event
extension never renew an existing registration. Unknown legacy periods are not
invented or automatically deleted.

`cleanup.expire_photos()` retains its scheduler-compatible name but now deletes
expired identifiable registrations (photo, embedding and profile), deferring while
an associated missing case is nonterminal. It fences registration changes before
Storage deletion and retains references on failure for retry. Guardian accounts
are untouched. Associated terminal case details are minimized during expiry cleanup.

The separate terminal-case scrubber still runs 24 hours after `closed_at` and
retains only documented statistics. Found photos remain separate: delete on ending
identification or confirming a match; interrupted deletion is retried.

The opt-in local maintenance worker (`RADD_LOCAL_JOBS=1`, one backend worker) checks
every 60 seconds. Production scheduling remains a separate deployment decision.
Do not run cleanup against live data merely to test it. The terminal-case query
requires the existing `cases(status ASC, closed_at ASC)` Firestore index.

See [registration retention setup and validation](../docs/registration-retention.md)
for the model, preview-first event configuration and legacy-data limitations.

## Push (FCM)
An ADDITIONAL delivery channel alongside the Firestore notification records above (cases.create/`_terminate`, volunteer_workflow.confirm/handover_found) -- never a replacement for them, and never allowed to affect the business operation it rides along with. `app.push.notify_guardian` fires right after the same notification doc is written, wrapped in its own try/except at every call site as well as internally, so an FCM exception (or the whole `messaging.send_each` call raising) can never fail case creation/transition/match confirmation/handover, nor stop the notification doc from being written.
Payload is minimal and data-only: `kind`, `status`, `case_id`, `event_id` -- no name, exact age, photo, guided-report/free text, location, contact info, or registration token. The client treats it purely as a hint to refetch from the authenticated backend, never as authoritative state.
Per-registration send results are handled independently (`messaging.send_each`, a batch call): one Guardian installation's registration failing has no effect on delivery to that Guardian's other registrations. A registration is removed ONLY on Firebase's own `messaging.UnregisteredError` -- its definitive "this no longer exists" signal. Every other outcome (network/service failure, quota, a generic invalid-argument not specifically about the registration itself) is treated as transient and leaves the registration untouched for the next event to retry against.

**Locale**: `locale` on a registration selects which of two fixed, pre-translated notification strings a push is sent in -- it is resynced (via `PUT /v1/guardian/fcm-registrations`, same idempotent upsert) whenever the Flutter client notices its own current in-app language may have changed, so an already-registered installation's push language stays current without a restart, logout, or token rotation. A resync that fails (e.g. offline) leaves the previous locale in place server-side; the client retries at its next opportunity rather than this endpoint tracking staleness itself.

**Logout / account switch**: `POST /v1/guardian/fcm-registrations/unregister` deletes the caller's own registration for a given token -- scoped to `self.user`, so it can never target another Guardian's registration, and idempotent (deleting an absent document is a no-op, so a retried call from a flaky logout is safe). This is a client-driven best-effort cleanup; if it never reaches the server (the installation was offline at logout, or the app was killed without a clean sign-out), the registration is not left as a permanent cross-account leak: `register_fcm_token` sweeps away any OTHER Guardian's registration for the exact same token before upserting the caller's own, so the very next registration on that installation (by whichever Guardian signs in next) closes the gap. A Guardian's own second (or further) device is never touched by this sweep -- only an exact token match under a *different* uid is removed.

## Guardian verification contract (for the Volunteer app)
Two ways for a Volunteer to verify the Guardian of THEIR current case, both only while that case is `awaiting_guardian_verification`, both recorded on the case as `guardian_verification` (`method`, `volunteer_uid`, `guardian_id`, `case_id`, `verified_at`) and both authorizing `POST /found-reports/{id}/handover` (which keeps the recorded method on the handover record):
- `POST /v1/volunteer/found-reports/{id}/verify` `{payload}` — the Guardian's ACCOUNT-level QR (`radd:guardian-verification:v1:{guardian_uid}:{nonce}`, issued by `POST /v1/guardian/verification`, 5-minute, single-use). The backend checks the scanned Guardian is the one associated with the Volunteer's current case; scanning can never affect any other case (`method: qr`).
- `POST /v1/volunteer/found-reports/{id}/verify-identifier` `{case_id}` — the case-specific fallback when the QR cannot be displayed/scanned: the Guardian shows the case identifier from their signed-in app (the QR tab's "Show Case Identifier", displayed as `#RD-…`); the Volunteer submits it and it must equal their current case's id exactly (`#`/case-insensitive tolerant). A mismatch records nothing (`method: case_identifier`).
Every Volunteer-driven status change now also writes the Guardian's own notification record (`users/{uid}/notifications/{case}-{status}`) and fires the best-effort push: Search in Progress (first join), Match Confirmed, Awaiting Guardian Verification, Reunited.

## Development case-state command
The Guardian app only reacts to backend state; the stages after Report Received are written by the Volunteer workflow. Until the Volunteer app is integrated, `scripts/dev_case_state.py` advances a real case one stage at a time writing exactly the same canonical fields (status, `stage_timestamps`, `updated_at`, the Guardian notification record, the push) so every Guardian screen can be exercised now against real Firestore. Local only, existing Admin credentials only, and it refuses any event whose `environment` is not `development`:
```powershell
backend/.venv/Scripts/python backend/scripts/dev_case_state.py --list
backend/.venv/Scripts/python backend/scripts/dev_case_state.py --case-id RD-XXXX --to awaiting_guardian_verification
```

## Tests
```powershell
backend/.venv/Scripts/python -m pytest backend/tests
```
Unit/API tests use isolated fakes only; they do not seed production.


## Volunteer/shared completion update

The local runner now enables one-minute maintenance (retention and Volunteer
push retries). See [manual keyless Firebase setup](../docs/firebase-local-setup.md)
for the approved local setup; the earlier text above describing unscheduled
retention and unimplemented Volunteer push is superseded by this section.
No live Firebase verification is claimed until that manual setup is complete.

Volunteer login/reset/logout now reuse the shared Flutter authentication UI and
service. Inactive accounts are denied even profile/ID access. The client clears
protected state and signs out when a protected request detects deactivation.

`PUT /v1/volunteer/fcm-registrations` accepts the device token, locale and optional
foreground latitude/longitude. It reuses `users/{uid}/fcm_registrations`, associates
the active event and verified Firebase token expiry, and never accepts a UID.
`POST /v1/volunteer/fcm-registrations/unregister` removes only that user's device.
Locations expire after 60 seconds without a foreground heartbeat; the app clears
location on pause and collects no background positions. Denied location does not
prevent general alerts. Priority notifications use the same case and 500 m radius.
Delivery receipts and expiring send leases suppress concurrent/repeated sends;
FCM remains at-least-once across a crash between sending and recording success.

Selected profile details expose only associated Guardian name, phone and
relationship to an authorized active Volunteer; list responses omit contact.
Camera capture uses preview/retake/use. The real Found Report precedes manual
review. The AI endpoint remains explicitly unavailable, with no generated scores.

`POST /v1/volunteer/found-reports/{id}/end` closes only an unmatched identification
attempt. Confirmation or explicit end makes the photo inaccessible immediately
and deletes it synchronously before reporting success. Storage failures return
503, retain a retry reference and reuse the durable cleanup queue; the local
worker retries. The case transaction and Storage deletion are not one atomic
operation: a failed delete can leave a confirmed/ended report with deletion
pending, but it cannot expose the image or report that deletion succeeded.
Back navigation does not invoke this endpoint.

Registered photos follow explicit registration expiry with active-case deferral;
terminal case scrubbing remains 24 hours after closure. Age-group buckets now match the latest proposal:
0–5, 6–17, 18–59 and 60+. Guardian location denial can complete guided reporting
without coordinates and without a priority alert. Existing Guardian UI/workflows
and shared records otherwise remain in place.
