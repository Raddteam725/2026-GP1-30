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
POST/GET /v1/cases; GET /v1/cases/{id}; PUT /v1/cases/{id}/guided-report; POST /v1/cases/{id}/cancel; POST /v1/cases/{id}/resolve; POST /v1/guardian/verification. GET/PUT /v1/notifications. A Guardian may hold at most one active case per individual; creating a second while one is active is idempotent and returns the existing one — once terminal, reporting again always creates a genuinely new case (never reuses or overwrites the old id). Reporting also fails closed (409 `photo_expired`) if the individual's registered photo is not currently fresh — see Retention below; this is enforced here, not only by the Flutter UI's own prompt. Guardian-side terminal outcomes are `cancelled` (mistaken report) and `resolved` (Guardian found the individual independently) via the two endpoints above; `reunited` and `transferred_to_authority` are Volunteer/Admin-only transitions, not reachable from this API. Guardians otherwise cannot set case status directly — sequential progression (`report_received` → … → `awaiting_guardian_verification` → `reunited`) belongs to Volunteer/Admin services with role and verification checks. A closed case is retained (never deleted outright) until the retention job scrubs it 24h after `closed_at` — see Retention below. Guided-report answers become read-only once `completed: true` (409 `report_already_submitted` on further writes) — not a permanent editable chat session. `POST /v1/guardian/verification` issues an account-level QR payload (never per-case): an opaque nonce tied server-side to the Guardian's UID, consumed by whichever case a Volunteer is currently confirming (`VolunteerWorkflow.verify_guardian`) — it carries no case ID, password, or PII.
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
Two independent 24-hour timers — never combined, never derived from an event day/date or a client clock:
- **Registered photo (per individual):** `photo_captured_at` (server timestamp, stamped by `service.save` whenever a *new* photo is uploaded — editing other fields does not touch it) is the sole authority. `service.photo_expired(data)` treats a photo as expired once 24h have passed, or immediately if `photo_captured_at` is missing (never assumed fresh without proof). This is checked authoritatively at the point of use — `GuardianService.photo()` (404 `photo_expired`) and `CaseService.create()` (409 `photo_expired`, so Report Missing is blocked) — independently of whether the sweep below has run yet. The individual's profile itself is never deleted by this; only the stale photo reference and its Storage object are, once `cleanup.expire_photos()` runs.
- **Terminal case (per case):** 24h after `closed_at`, `cleanup.scrub_terminal_cases()` replaces the case document with only `status`, `created_at`, `closed_at`, `age_group`, `event_id`, `scrubbed_at`, and — only for a `reunited` case — `handed_over_by` (the one Volunteer reference the documented "Reunited Cases by Volunteer" statistic needs). Every other field (guardian_id, individual_id/name, exact age, guided_report, guardian_verification, confirmed_by/joined_by/found_report_id, stage_timestamps, …) is gone — a scrubbed case can no longer be linked back to its Guardian or individual (it also disappears from that Guardian's own case list, since `guardian_id` is what that query filters on). `found_reports` linked to the case (and their Storage photos), `alerts`, and both Guardian- and Volunteer-side notification documents for that case are deleted outright, not scrubbed-in-place. The registered individual's own profile is untouched — its lifecycle is governed solely by the photo timer above and the Guardian's own explicit delete.

Both jobs (`app.cleanup.expire_photos`, `app.cleanup.scrub_terminal_cases`) are idempotent and safe to run concurrently with themselves: an already-cleared photo/already-scrubbed case is a fast no-op. **Storage-deletion contract**: a Firestore reference to a photo (an individual's `photo_path`, or a `found_reports` document) is never cleared/deleted unless `_delete_blob` confirms the underlying Storage object was actually deleted or was already gone — `_delete_blob` returns `False` on any failure and every call site leaves the reference exactly as-is in that case, so the next run retries the same object. `expire_photos`'s clear step also re-reads the document inside its own transaction and only clears if `photo_path` still equals the path it just deleted, so a slow retry can never remove a Guardian's newer replacement photo captured in the meantime.

This module is deliberately **not wired to any scheduler or deployment mechanism** at this stage — that decision (and its timing guarantee: a periodic sweep is bounded by its own interval, never exactly the 24-hour instant, unlike e.g. a per-item Cloud Tasks dispatch) is deferred to the deployment stage. During development, run
```powershell
backend/.venv/Scripts/python -m app.cleanup
```
(also drains the photo_cleanup queue) manually for controlled verification against a real Firebase project with the same server credentials. `scrub_terminal_cases`'s query needs the composite index in `firestore.indexes.json` (`status` ASC, `closed_at` ASC on `cases`) deployed once via `firebase deploy --only firestore:indexes` before it can run against real Firestore — a single-field range filter like `individuals.photo_captured_at` is auto-indexed and needs nothing extra, but combining an equality filter with a range filter on a different field is not.

**Known, deliberately unresolved gap:** a `found_reports` document that never gets matched to a case (`case_id` stays null) is not covered by either job — nothing in this codebase deletes an unmatched found-person photo today. Sprint-0 says such a photo should be deleted "when the identification attempt is concluded," which isn't tied to any case's terminal status, so it needs its own rule (and a definition of "concluded") on the Volunteer side — not invented here.

## Real-time contract (both roles)
FastAPI is the authoritative layer, Firestore the durable store, FCM the immediate SIGNAL, and the receiving app always refetches from FastAPI. For every case-state-changing operation, in this order and inside the same request: authenticate/authorize → validate the transition → commit the authoritative state AND the durable notification record(s) in one transaction → immediately attempt FCM to every eligible registration (`app.delivery.deliver`, one `messaging.send_each` batch per notification) → respond. Polling (Guardian Case Status 30 s fallback, Volunteer workspace poll) and the maintenance run are recovery only; the normal path never waits for either. A push payload is never the state: the client refetches `GET /v1/cases/{id}` / lists / notifications.

**Guardian → Volunteer** — `POST /v1/cases` (create): `cases/{id}` + `alerts` general intent + Guardian `notifications/{case}-report_received` in the transaction, then `volunteer_alerts.dispatch` → per eligible active Volunteer of the event `volunteer_notifications/{case}-new` (+ `-priority` when nearby) and the push. `PUT …/guided-report` re-dispatches (priority eligibility may now exist). `POST …/cancel` / `…/resolve`: the case is committed `cancelled`/`resolved` with the Guardian's `notifications/{case}-{outcome}`, then the Volunteers the existing participation model says were told about the case — `joined_by`, `confirmed_by`, and anyone holding a `volunteer_notifications` record for it (never every Volunteer) — each get a durable `volunteer_notifications/{case}-{outcome}` (`kind: case_closed`, `status: cancelled|resolved`) and an immediate push, even when they currently have no reachable device (record only). A closed case therefore never silently disappears from a Volunteer's list; `reunited` (the confirmer's own handover) produces no closure notice.
**Volunteer → Guardian** — `start-search` (first join), `confirm-match`, `begin-verification`, `handover` each write `users/{guardian}/notifications/{case}-{status}` in their transaction and push the Guardian immediately (`app.push.notify_guardian`).

**FCM `data` contract** (identical shape both directions; `notification` is a fixed generic string pair chosen by the registration's `locale`):
`role` (`guardian` | `volunteer`), `kind`, `status`, `case_id`, `event_id`. Guardian kinds: `case_created`, `status_update`, `status_changed`. Volunteer kinds: `general`, `priority`, `status_update`, `case_closed`. Nothing else — no name, exact age, photo, free text, location, contact info, or token. Clients validate `role`, de-duplicate on (`case_id`, `status`) and refetch; a newer status for the same case is a new event and must never be suppressed.

**Volunteer client contract (to consume — Yara):** (1) on a foreground message with `role == volunteer` refetch `/v1/volunteer/cases/available`, `/cases/mine` and `/notifications` (already the `onRefresh` path); (2) `kind: case_closed` (`status: cancelled|resolved`) means the case has left the joinable/mine feeds (`visible()` hides terminal cases) — move it out of active-search presentation and rely on the durable `volunteer_notifications/{case}-{status}` record (`kind: case_closed`) for the explanation in the notification list; (3) render `kind: case_closed` in the notification list (today an unknown kind falls back to "new case" in `api_volunteer_repository.dart`); (4) de-duplicate on (`case_id`, `status`) rather than refetching per message; (5) on app resume, refetch once (recovery); (6) keep `PUT /v1/volunteer/fcm-registrations` on token refresh/locale/location changes — nothing new is required for session validity (see below).

**Delivery, receipts, retry** (`app/delivery.py`, shared): each notification document carries `deliveries/{registration}` receipts; a 60 s lease prevents a request and a reconciliation run sending the same message twice; `sent_at` marks FCM acceptance. A registration is removed ONLY on Firebase's own `messaging.UnregisteredError`; every other failure (network, quota, a whole `send_each` call raising) leaves no receipt so the message is retried by the maintenance run (Volunteer: `local_jobs.retry_alerts` for open cases and cases closed within retention; Guardian: `push.retry_recent` for the last hour of notification records). Every Firebase Admin HTTP call is capped by the app option `httpTimeout` (`FIREBASE_HTTP_TIMEOUT_SECONDS`, default 10) so an already-committed transition can be delayed by a stalled push network path by at most that bound, never hung, and never rolled back.

**Registration session lifecycle** (`app/sessions.py`, shared): a registration is stamped from the VERIFIED ID token at upload (`session_expires_at` = `exp`, `auth_time`). While `session_expires_at` is in the future it is trusted. Once it has passed the registration is NOT dropped — the account's session is re-checked with Firebase Auth (`auth.get_user`): disabled, or refresh tokens revoked after this registration's sign-in (`tokens_valid_after_timestamp` > `auth_time`), removes it; a live session is trusted for one more token lifetime (1 h) and re-checked after that; a transient Firebase failure skips this attempt only. So an hour of normal ID-token refresh never silently ends delivery, nothing is valid forever without Firebase confirming it, and logout/account switch/revocation/disable/inactive-Volunteer all still stop delivery.

**Timing instrumentation** (development-safe, identifiers and durations only): `Radd API: METHOD /path -> status (N ms)` per request (T1→response), `Radd timing: T3 committed op=… case=… commit_ms=…`, `T4 volunteer dispatch …`, `T5 push notification=… attempted/sent/failed/removed fcm_ms=…` on the backend; `T6 push received`, `T7 refetch begin`, `T8 refetch done` in the Guardian app's debug log. No tokens, names, text or locations are ever logged.

**Maintenance boundary**: `POST /internal/maintenance` (header `X-Radd-Maintenance-Token`, only when `RADD_MAINTENANCE_TOKEN` is set; 404 otherwise) runs `local_jobs.run_once` once — the hook for Cloud Scheduler on Cloud Run. `RADD_LOCAL_JOBS=1` (set only by `run_dev.py`) starts the local in-process minute loop instead; the deployed API service must leave it unset.

## Push (FCM)
An ADDITIONAL delivery channel alongside the Firestore notification records above -- never a replacement for them, and never allowed to affect the business operation it rides along with. Every call site wraps `notify_guardian` / `safe_dispatch` in its own try/except as well as internally, so an FCM exception can never fail case creation/transition/match confirmation/handover, nor stop the notification doc from being written.
Payload is minimal and data-only: `role`, `kind`, `status`, `case_id`, `event_id` -- no name, exact age, photo, guided-report/free text, location, contact info, or registration token. The client treats it purely as a hint to refetch from the authenticated backend, never as authoritative state.
Per-registration send results are handled independently (`messaging.send_each`, a batch call): one Guardian installation's registration failing has no effect on delivery to that Guardian's other registrations. A registration is removed ONLY on Firebase's own `messaging.UnregisteredError` -- its definitive "this no longer exists" signal. Every other outcome (network/service failure, quota, a generic invalid-argument not specifically about the registration itself) is treated as transient and leaves the registration untouched; the maintenance run retries the message (see Real-time contract above).

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
the active event and the verified Firebase token's session (`session_expires_at`,
`auth_time` — re-confirmed with Firebase Auth rather than expiring silently, see
"Registration session lifecycle" above), and never accepts a UID.
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

Registered photo expiry remains 24 hours; terminal case scrubbing remains
24 hours after closure. Age-group buckets now match the latest proposal:
0–5, 6–17, 18–59 and 60+. Guardian location denial can complete guided reporting
without coordinates and without a priority alert. Existing Guardian UI/workflows
and shared records otherwise remain in place.
