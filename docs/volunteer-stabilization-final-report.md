# Radd Volunteer — consolidated stabilization report

Date: 2026-09-28. This report consolidates the reviewed working-tree implementation;
older pass reports are historical. It is not a claim of production deployment or
completion of the controlled device tests below. All previous uncommitted work was
preserved. No commit, push, Firebase migration/write, cleanup execution, APK installation,
or mutating emulator action was performed in this stabilization pass.

## 1. Implemented Volunteer functionality

Shared Firebase login and Forgot Password; role routing and persisted-session entry;
authoritative account/assignment profile and Digital Volunteer ID; location gate and
Android participation location service; Missing Case lists and concurrent Start/Join;
real camera/capture/preview/retake/use-photo; independent Manual Review; camera and
manual-only Found Reports; explicit confirmation/contact; shared QR/identifier and
handover; durable notifications, foreground banners and system-push configuration;
Arabic/English and Guardian-aligned components. Actual AI and Admin UI are not implemented.

## 2. Changes in this stabilization pass

Two inconsistencies were corrected:

- `profile_detail(..., case_id=...)` previously returned Guardian contact merely because
  an open case matched the selected profile. It now returns no contact at browsing/detail
  time, consistent with the confirmed-context boundary for both origins.
- `registration_available` previously considered a Missing Case deletion hold sufficient
  for general eligibility. Its default now requires an unexpired known registration.
  Existing authorized case reference access opts into `case_context` explicitly. General
  Manual Review/profile-photo access and new manual-only confirmation cannot revive an
  expired registration. Existing Missing Case confirmation and authorized reference access
  retain their case-specific hold behavior. Standalone identified-FR holds remain scoped
  to their already-confirmed report, not general review.

Added/updated regression expectations for these boundaries. No user-facing redesign or
new product feature was introduced. Prepared all six requested Terms/Privacy drafts and
future consent design; no gate or acceptance persistence was implemented.

Files changed in this pass: `backend/app/registration_retention.py`,
`backend/app/service.py`, `backend/app/volunteer.py`,
`backend/app/volunteer_workflow.py`, `backend/tests/test_volunteer_workflow.py`;
new `docs/volunteer-terms-privacy-drafts.md` and this report. Retention documentation
was updated to distinguish general expiry from context-scoped holds. Formatting
10 relevant Dart files made zero changes. Other working-tree changes predate this pass.

## 3. Account and assignment

`users.active` and `events/{eventId}/volunteers/{uid}` are separate. Assignment means
that document exists, including an empty document. Profile API returns `assigned`
and `event_id`; Digital ID reads these values. Unassigned users cannot use protected
event APIs. Deactivated/revoked users lose protected state and use shared logout.
Reactivation does not fabricate assignment; access can return after authentication if
other requirements remain valid. Operator scripts are trusted development tools, not
public Admin routes.

## 4. Mandatory location

The production workspace explains that location permission and enabled Location Services
are required before requesting permission. Missing access blocks event views/actions;
Profile/ID do not grant event access. Denial allows appropriate retry, permanent denial
uses app settings, services-off uses location settings. Actual state is rechecked on
resume and recovery. Valid permissions/services without a GPS fix permit participation
and standard alerts, but no proximity priority. No local preference grants permission.
The explanation is a blocking/recovery view, not a modal repeated on every tab change.

## 5. Background location

Authorized active participation configures the existing Geolocator Android foreground
location service and ongoing notification. Event loss, unassignment, deactivation,
logout, permission loss or disabled services stop access/updates through existing
lifecycle handling. Background authority changes require an event or a successful
recovery check; instantaneous reaction to an offline remote change is not claimed.
Latest estimates expire for proximity use and approximate/invalid estimates are not
presented as a reliable 500-metre signal. Live lifecycle tests remain necessary.

## 6. Start / Join Search

Report Received + unjoined shows Start Search. The first participant is added
transactionally and changes the same case to Search in Progress. Other Volunteers
still see it available; their action is Join Search. Additional joins preserve status
and do not duplicate participation or the case. My Cases reconstructs membership from
the backend. Confirmation removes the case from other participants' active lists and
retains access for the confirming Volunteer to verify/handover.

## 7. Cases screen

Only Available Cases / My Cases, representing Guardian-created Missing Cases. No Found
Report cards, sections or tabs. Existing status/action styling is retained.

## 8. Report screen

Primary Open Camera followed by secondary Manual Review. Unfinished Found Reports are
resumable here. Manual Review is not a Home or bottom-navigation destination.

## 9. Camera / AI boundary

Real in-app capture → preview → Retake or Use Photo → saved Found Report → ready
identification screen. Find Match with AI is primary and Manual Review secondary.
Use Photo does not automatically invoke AI. Photo submission is required by the camera
endpoint; AI candidate requests reject a report lacking a photograph. The actual engine
is unavailable; no generated candidates/scores/automatic identity are substituted.
Existing ready/processing/results/no-reliable-result/unavailable/error states remain.

## 10. Camera-less Manual Review

Initial Report → Manual Review browses eligible Active Event registrations, not merely
cases or AI candidates. Name search, gender filter, clearing and no-results state remain.
Profile selection does not confirm identity or expose contact. Explicit confirmation
calls the authenticated manual endpoint with request_id/profile_id; the shared transaction
creates and links the report atomically. No placeholder photo or Missing Case is created.
Retries use the same deterministic ID while retrying that operation.

## 11. Standalone Found Report model

Collection `found_reports`, separate from `cases`. Camera reports start in
identification_in_progress. Manual-only reports first commit as identity_confirmed with
`origin=volunteer_found`, `identification_method=manual`, `ai_status=not_requested`,
no photo_path, and event/reporter/confirmed profile references. Subsequent states:
identity_confirmed → awaiting_guardian_verification → reunited. Explicit ended attempts
use the existing ended flag. Reporter ownership and current event authorization remain.
No standalone FR contributes to Guardian Missing Case counts.

## 12. Linking origins

If a Missing Case exists, confirmation links the Found Report to that case. If an
identified Found Report exists first, a later legitimate Guardian report preserves the
real Missing Case origin and links the existing workflow at the appropriate found/
verification stage, without an unnecessary search alert. Verification proof is transferred
transactionally as required. No synthetic RD identifier or duplicate handover is introduced.

## 13. Guardian contact boundary

Public review/list/detail output contains no Guardian contact, including case-backed
profile browsing after this fix. Authorized confirmed report details resolve the associated
Guardian's actual contact. Ownership, role, enabled state and event assignment remain
checked; profile selection alone never grants contact access.

## 14. QR / identifier verification

Shared reunification context resolves the real Missing Case or standalone Found Report.
Guardian QR checks include Guardian association, event, expiry, single-use consumption
and confirming Volunteer/context. A failed QR/identifier check clears proof and prevents
handover. The fallback uses the real RD or FR identifier displayed inside the Guardian's
authenticated account on their device. It does not authorize handover merely because an
arbitrary supplied string exists. The physical comparison step remains a Volunteer duty.

## 15. Handover

Successful verification permits explicit handover; it alone does not mark Reunited.
Handover records completion and Volunteer metadata transactionally. Completed reports
cannot be restarted/reidentified. Active workflow lists cease exposing the completed
operation. Existing Guardian case status/notification behavior remains for linked cases.

## 16. Registration retention

Current event options define registration periods. Guardian does not choose an event;
backend resolves the single Active Event and valid options. Longest valid default applies.
Server stores registration_started_at, registration_expires_at, registration_period_id,
registration_duration_hours. Photo age alone does not expire data. Photo replacement and
event extension do not extend existing expiry. Registered photo and future embedding
share the registration retention lifecycle. No legacy registration was migrated.

Deletion holds preserve necessary data for an approved active Missing Case or identified
Found Report. They do not extend expiry or re-enable general review. Context-specific
case/report access remains authorized separately. Cleanup deletes due identifiable data
once all holds end, with fencing/path checks and retry on storage failure, not accounts.

## 17. Found Report retention

Found photos are temporary and deleted on ended unmatched attempts or immediately after
confirmed identity, with durable retry for interrupted deletion. Manual-only reports have
no image. Verification/handover do not depend on a deleted Found photo. Standalone Reunited
uses the centralized minimal allowlist: internal ID, origin, event, outcome, necessary
timestamps, handed_over_by and verification_method. No person/Guardian linkage, contact,
snapshot, photo or QR secret remains. Valid registrations continue to their own expiry;
expired registrations become due once the last hold ends. No new FR duration was invented.

## 18. Notification idempotency / history

Stable per-user event document IDs preserve history/read state. FCM registration no longer
redispatches historical cases. History older than a new registration is not pushed to it;
read notifications are not re-pushed. Existing per-registration sent receipts/leases and
recovery handle failed sends. Persistent per-user/event foreground ID memory suppresses
repeated foreground presentations across sessions. Fetching history does not create banners.
A transport crash between FCM acceptance and receipt write remains an external-delivery
ambiguity; application logic does not claim exactly-once FCM transport.

## 19. Foreground / background notifications

Foreground onMessage → in-app banner and targeted refresh. Background notification+data
payload → Android system notification, without a duplicate local Dart notification.
Volunteer channel radd_volunteer_alerts uses high importance and stable tags; permission
request and onMessageOpenedApp/getInitialMessage routing remain. Standard alerts do not
wait for Guided Assistant location. Priority uses the shared configured 500-metre radius
and valid recent coordinates; it does not create a case. No new FR push category exists.
Session validity/revocation still applies; normal token renewal refreshes registration.

## 20. Localization

Existing Arabic/English resources, RTL/LTR layouts and shared Radd styles remain. No new
runtime text was introduced in this stabilization pass. Six bilingual review drafts are
separate documentation, not hard-coded UI or enforced legal content.

## 21. Security / authorization and its current limits

Backend verifies Firebase sessions and role/ownership/event authority for protected reads
and writes. Knowing an identifier does not authorize another Guardian's or Volunteer's
private workflow. No public Admin operation was added. Repository Firestore/Storage rules
remain deny-all to direct clients; this pass did not redeploy/audit remote rules. Admin SDK
access is through the backend and trusted operator environment, never client credentials.
No credentials were printed, created or stored by this pass.

Release API configuration requires HTTPS. The debug APK intentionally uses the existing
local development URL http://127.0.0.1:8000 with adb reverse; that connection must not be
represented as HTTPS or a production endpoint. Cloud deployment remains separate.

Actual Android permission/services are checked on-device. Current backend checks do not
independently attest those OS states. A stronger device-participation server contract is
not invented here; clarification was requested whether to document the current boundary
or propose such a contract before implementation. No GPS coordinate is treated as proof
of permission. This limitation is material to interpreting AG, not hidden by the UI tests.

## 22. Future Admin compatibility

Keep existing account-management/assignment services, event/period configurator, case
structures, participation records, internal found_reports.monitoring query and retention/
minimal statistical records. A future Admin API must authenticate/authorize callers before
invoking trusted management services. There is no Admin UI, public Admin authorization
implementation or new statistical schema in this pass.

## 23. Development Firebase state relevant to testing

Last supplied/read-only verified context, not newly mutated in this pass: Lina VOL-TEST-001
and Saud VOL-TEST-002 are test Volunteers; Active Event C8fES02usly6UXgMh6sl has test periods.
test123 is valid and linked to FR-2b6e7a21402fd4f5b06012df4afbfffb7b738545, awaiting Guardian
verification. Resume that report rather than confirm test123 again. Keep Saud's approved
join to RD-03823AFEEC94. The 17 legacy registrations remain unchanged and not inferred valid.
The prior manual failure was stale-server HTTP 405, not missing-photo validation; the
static manual route diagnostic and HTTP-level regression remain.

## 24–28. Validation results

| Check | Result |
|---|---|
| Dart formatting | 10 relevant files checked, 0 changed |
| Full Flutter suite (including Guardian regressions) | 211 passed |
| Full backend suite | 199 passed; 56 existing SDK deprecation warnings |
| flutter analyze | No issues |
| git diff --check | Passed |
| Unmerged paths | None |
| Android debug build | Succeeded; existing Kotlin migration advisory |

APK: build/app/outputs/flutter-apk/app-debug.apk, local development URL as above.
Build is not installed. Backend code changed since its last startup; restart with the
reviewed code before controlled testing, keeping RADD_LOCAL_JOBS=0 unless a cleanup run
is separately approved. No live latency benchmark was run: the five-second target remains
a controlled-test requirement, not a guarantee derived from unit tests. Existing immediate
processing indicators and asynchronous notification dispatch remain; no new blocking I/O
was introduced.

## 29. Exact controlled live tests still required

1. Install reviewed APK/restart reviewed backend; verify correct runtime route/base URL.
2. Valid assigned account restore and Digital ID; controlled unassignment/deactivation/
   reactivation only with explicit operator approval; verify location stops/access changes.
3. Permission denial, revocation, one-time permission expiry and Location Services off/on;
   mandatory explanation/recovery and no repetitive dialog while access remains valid.
4. Valid permission/services with unavailable GPS; standard workflow stays available,
   priority excluded until valid fix. Background location continues only during authorized
   participation, stops on logout/event loss, including slow/offline lifecycle observations.
5. Two real Volunteers Start/Join the same legitimate case; refreshed/relogged My Cases;
   one confirms, other loses active handling and receives the appropriate update.
6. Real device camera capture, preview, Retake, Use Photo, both identification actions;
   Manual Review directly from Report without camera/AI; no contact before confirmation.
7. Current test123 report: Guardian displays genuine QR/context identifier; scan real QR
   or use approved authenticated-account fallback; invalid proof blocks handover; valid
   proof alone is not Reunited; explicit handover completes exactly once.
8. Verify appropriate Guardian/Volunteer status/history updates after completion. Audit
   retention/minimal output read-only. Do not trigger real deletion merely for demonstration.
9. New authorized case alerts in foreground, Android home, another app and background;
   system-notification tap opens the authorized current case or a correct closed-status
   message. Observe real duplicate suppression across restart/login/token renewal and
   ensure the next genuinely new event is still delivered.
10. Controlled timing T0 Guardian action → backend commit/send → Volunteer event/banner/
    refresh; standard screens/submissions against the five-second target. Record network,
    backend and device conditions. Push latency is not guaranteed by Radd.

None of these newly listed live mutations was performed automatically in this pass.

## 30. Unresolved decisions / approvals

- Terms/Privacy text and proposed draft versions require review before any consent gate
  or acceptance persistence. Operator identity/contact and eventual consent-audit retention
  require approved values. No legal finality is claimed.
- Whether a server-side device-participation contract is additionally required for OS
  location conditions is pending clarification; current client/backend boundary is above.
- Production hosting/scheduler remain separate. Current local executor/retry and opt-in
  cleanup are not a Cloud Run deployment plan.
- Ended unmatched Found Report metadata and local notification-presentation memory have
  no newly approved purge duration; this pass does not invent one. Approved photograph
  deletion and completed-FR minimization remain implemented.
- Real AI integration remains the intentional functional postponement. Admin UI remains
  a later sprint. These are not implemented with mocks as substitutes.

## Terms / Privacy — separate DRAFT / FOR REVIEW output

See [all six bilingual drafts and proposed consent design](volunteer-terms-privacy-drafts.md):
English Terms, Arabic Terms, English Privacy update, Arabic Privacy update, English consent
summary and Arabic consent summary. Proposed terms_version and privacy_version are both
`draft-2026-09`. They are not enforced, published as final, or persisted as accepted.
