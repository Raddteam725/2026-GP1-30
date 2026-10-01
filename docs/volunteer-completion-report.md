# Radd Volunteer/shared implementation report

Local implementation continues on the existing `volunteer` working tree. No commit,
push, merge, rebase, reset, branch switch, or credential creation was performed.
The latest proposal and the user's subsequent approvals define the behavior below.
Actual AI face recognition is the only intentionally deferred application feature.
Live Firebase and physical-device verification remain blocked by manual Admin
credential setup, not replaced by simulated production data.

## Screens and shared authentication

No replacement Guardian screen or separate app/backend was created. The existing
Volunteer Home, Available/My Cases, Report, Manual Review, Match Details, Guardian
Contact, Verification, Handover, Digital ID, Profile and Notifications remain.
The camera screen now holds the actual capture for preview, Retake and Use Photo;
there is no gallery picker. The matches/fallback screen adds a confirmed End
Identification Attempt action. Case details include creation/update times and
actual last-seen coordinates when present. Registered relationship values use
shared localized labels; custom relationship descriptions remain entered data.

VolunteerEntry now uses Latifa's AuthScreen, AppServices.auth and shared reset
route. The unused duplicate VolunteerAuthService and runtime preview-login button
were removed. Shared login resolves the actual stored account role regardless of
which role's login entry was selected. Signup remains Guardian-only. Existing
validation and generic reset confirmation remain. Both explicit role logouts
return to the shared Login screen and remove protected navigation history.

Inactive Volunteer profiles are denied by the backend, including Digital ID.
When a protected request detects deactivation, the app clears repository data,
hides the workspace, removes push registration, clears image caches, uses shared
logout and opens Login with an Arabic/English deactivation notice. Firebase Auth's
disabled-account error also has a distinct backend response. No privileged
inactive-ID mode exists. The visual ID component still renders no green animation
for an inactive value in isolated component tests; only an active authenticated
account can actually reach it. Detection uses existing foreground polling and
requests, not a new continuous account-monitoring architecture.

## Real data sources and workflow checklist

| Requirement/screen | Implemented source/behavior |
| --- | --- |
| Login/session/profile/ID | Same Firebase Authentication; backend reads `users/{authenticated uid}` for role, account status and identity. No client-selected UID grants access. |
| Available Cases | Same top-level `cases` created by Guardian; current event and joinable stages only. Authenticated API enforces visibility. |
| Case Details | Shared case, registration photo and persisted Guided Assistant answers. Missing optional data is not fabricated. |
| First Start Search | Existing Firestore transaction adds UID once and changes Report Received to Search in Progress with shared timestamps and Guardian notification. |
| Additional Start Search | Appends independent participation without another status transition; backend transaction/retry prevents duplicate participants. |
| My Cases | Persisted `joined_by` and `confirmed_by`; survives navigation, refresh and session restoration. |
| Shared status | Existing backend-driven polling/FCM refresh reads the same case for both roles. No separate Volunteer case copy. |
| General alerts | Guardian transaction persists shared alert intent. Real FCM dispatcher targets enabled Volunteers with current-event, unexpired authenticated device registrations. Durable in-app history uses existing Volunteer notification subcollections. |
| Priority alerts | Real foreground location, permission first, 500 m radius, only Guardian-confirmed valid last-seen coordinates. Same case, separate priority alert. No coordinates means general only. |
| Device lifecycle | Existing `fcm_registrations` collection, hashed token IDs, token rotation, locale synchronization, logout removal and FCM token deletion. Cross-role account changes clear stale registrations for that exact token. |
| Location lifecycle | Existing device position stream stops in background. Pause clears the server's location; 60-second freshness bounds stale locations if the network/process disappears. Foreground polling renews the heartbeat. |
| Found Individual | Real in-app camera → preview → retake/use → authenticated, event-scoped Found Report and private Storage photo. Existing request ID makes submission retries idempotent. |
| AI boundary | Returns explicit unavailable state and offers Manual Review. No embeddings, facial comparison, calculated similarities, invented candidates or confidence decisions. Existing candidate UI remains ready for later model integration. |
| Manual Review | Real current-event eligible registrations and protected photos; name search, gender filter, clear and empty results; details fetched separately. |
| Guardian Contact | Selected profile details expose only the associated Guardian's name/phone/relationship to authorized active Volunteers. List responses continue to omit contact. Includes custom relationship details and guided case information. |
| Confirm Match | Existing transactional human decision, no AI prerequisite. Updates shared case and preserves only the confirmer's My Cases visibility. Other joined Volunteers get persisted notifications and FCM delivery attempts/retries. |
| Found before missing | Existing confirmation creates one shared case associated with the real Guardian/registration when no missing case exists; no fake missing report required. |
| QR | Existing Guardian QR is verified server-side against the case's actual Guardian, expiry, consumption and confirming Volunteer. Existing compatibility for case-bound QR remains. |
| Alternative verification | Existing authenticated-account acknowledgement plus comparison of the case identifier. Failed comparison cannot authorize handover; method is recorded separately. |
| Handover | Explicit human confirmation after verification. Same case becomes Reunited and records the confirming Volunteer and closure time. QR success alone does not reunite. |
| Terminal cases | Existing rules exclude terminal cases from new joins and normal search transitions. Guardian Cancelled/Resolved functionality preserved. |
| Digital ID | Actual logged-in Volunteer name/ID/status, continuous green animation only for Active. No inactive authenticated access. |
| Localization | Existing English/Arabic ARBs retained and extended, generated with Flutter gen-l10n; selected language persistence and RTL/LTR remain. |
| Reliability | Backend success required before success UI; no production sample-data fallback. Photo deletion failures are explicit and retryable. |

## Found-report lifecycle and deletion

`POST /v1/volunteer/found-reports/{id}/end` is owner/event/active-account checked.
It atomically persists that the unmatched attempt ended. It does not mutate the
Guardian's case, case status, participation, or other Volunteers. Ended reports
cannot request candidates, confirm matches, reopen in the client, or retrieve
photos. Back navigation never invokes this action.

Match confirmation and explicit End immediately prevent photo reads and perform
Storage deletion synchronously before returning success. The image is not copied
to the case or registration. The client clears found-photo bytes and restores a
confirmed report without requesting its deleted image.

Firestore and Storage do not share an atomic transaction. If deletion fails,
the report's confirmed/ended state is persisted, the image endpoint is denied,
the API returns 503 (not success), and the deletion reference remains. Both
idempotent client retry and the existing cleanup queue/local worker can finish
physical deletion. A failed deletion may therefore temporarily retain an
inaccessible Storage object; the implementation does not claim otherwise.

## Shared Guardian/backend changes

- Preserved Guardian onboarding, signup, individuals, reporting, case status,
  account QR, notifications, cancellation/resolution, photo expiry and ownership.
- Guided reporting now allows confirmed same-location answers without coordinates
  when permission/services fail; it informs the Guardian and keeps general alerts.
  Partial coordinate pairs and coordinates after a No answer remain invalid.
- Explicit Guardian logout now goes to shared Login, as required by the shared
  logout acceptance criterion, while preserving locale and clearing history.
  GuardianGate distinguishes an ending authenticated session from a cold
  unauthenticated deep link, preventing startup navigation from racing logout.
- Guardian FCM now passes the existing named Firebase Admin app to `send_each`.
- Shared token registration deduplicates the same installation across both roles.
- Case age buckets now match the proposal: 0–5, 6–17, 18–59 and 60+. Retention also
  normalizes existing cases with an exact age before discarding that exact age.
- Existing retention services are invoked by approved local one-minute jobs.
  Notification delivery receipts are removed with retained-case debris.

## Local maintenance and notification reliability

`backend/run_dev.py` enables `RADD_LOCAL_JOBS=1`. FastAPI lifespan starts/stops one
local thread, running cleanup and Volunteer alert retries every 60 seconds. Each
job handles failure independently and retries; use one local server instance.
No separate Firebase project, backend, hosted scheduler, or cloud deployment was
created. After downtime, due deletions are attempted on the next running sweep.
The existing terminal-case composite Firestore index must be available.
The one-minute interval does not shorten retention: registered photos expire
24 hours after capture and terminal-case scrubbing waits 24 hours after closure.
Immediate found-photo deletion on match/end is a separate lifecycle rule.

FCM messages carry only generic localized text and case/event navigation context.
The client refetches authorized case state; a push payload never changes status.
Per-device delivery receipts and an expiring send lease prevent ordinary retry
and concurrent-dispatch duplication. Delivery is still at-least-once across a
crash between FCM acceptance and recording success. FCM acceptance is not proof
that a device displayed/read a notification. No fake/local push was substituted.

## Validation

- `flutter pub get`: successful; existing constraints retained. Twelve packages
  have newer versions outside the current constraints; no upgrade performed.
- `flutter gen-l10n`: successful from the final English/Arabic ARBs.
- `flutter analyze`: passed, no issues found.
- `flutter test`: 105 passed; includes Guardian regression tests,
  shared role routing/password reset, Volunteer API/deactivation and retention.
- `backend/.venv/bin/python -m pytest backend/tests -q`: 142 passed. Includes
  Guardian regressions, shared case/join/verification behavior, ownership and
  deactivation, both photo-deletion paths, failed Storage deletion/retry, real
  dispatch contract with the network sender replaced, proximity, token lifecycle,
  local jobs and keyless setup validation.
- Backend warnings: 29 deprecation warnings in the test stack and Firebase
  `Message.token`. FlutterFire provides FCM registration tokens, so the code does
  not incorrectly substitute them for Firebase Installation IDs.
- `git diff --check`: clean; unresolved conflict list empty. No conflict markers
  found in application/backend/test sources.

All automated backend tests use isolated Firestore/Storage fakes. Flutter tests
use test doubles where needed. These are verification fixtures, not reachable
production data sources. They do not establish actual Firebase transactions,
real credentials, real phone camera behavior or FCM device delivery.

## Remaining external verification

The latest local check found no default ADC file and no configured
`GOOGLE_APPLICATION_CREDENTIALS` environment variable. Live verification stops
at this manual setup step; renewed account access alone does not configure ADC. No private key was created,
downloaded, exposed or committed, and Android google-services.json was never used
as Admin credentials. The safe manual keyless ADC setup, exact product roles,
commands, local-server invocation and device checks are documented in
[firebase-local-setup.md](firebase-local-setup.md).

Still unverified: live Guardian/Volunteer login and hosted reset email, real
Firestore/Storage operations and index availability, FCM delivery/tap behavior on
a device, camera permission/capture/retake, actual location and 500 m boundary,
physical QR scanning, and complete real-device handover/retention. These require
the manual setup and real development accounts/devices. No production deployment
or cloud security-rule/IAM modification was performed. Actual AI face matching
remains intentionally absent as requested; no other function was postponed solely
because of its sprint number.

## Files changed

- `backend/README.md`
- `backend/app/alerts.py`
- `backend/app/case_models.py`
- `backend/app/cases.py`
- `backend/app/cleanup.py`
- `backend/app/firebase.py`
- `backend/app/local_jobs.py`
- `backend/app/main.py`
- `backend/app/push.py`
- `backend/app/service.py`
- `backend/app/volunteer.py`
- `backend/app/volunteer_alerts.py`
- `backend/app/volunteer_workflow.py`
- `backend/run_dev.py`
- `backend/tests/test_cases.py`
- `backend/tests/test_dev_setup.py`
- `backend/tests/test_fcm.py`
- `backend/tests/test_local_jobs.py`
- `backend/tests/test_retention.py`
- `backend/tests/test_volunteer.py`
- `backend/tests/test_volunteer_alert_delivery.py`
- `backend/tests/test_volunteer_workflow.py`
- `docs/firebase-local-setup.md`
- `docs/volunteer-completion-report.md`
- `lib/core/localization/arb/app_ar.arb`
- `lib/core/localization/arb/app_en.arb`
- `lib/core/localization/generated/app_localizations.dart`
- `lib/core/localization/generated/app_localizations_ar.dart`
- `lib/core/localization/generated/app_localizations_en.dart`
- `lib/core/routing/app_router.dart`
- `lib/features/auth/presentation/auth_screen.dart`
- `lib/features/guardian/presentation/guardian_gate.dart`
- `lib/features/guardian/presentation/guardian_home_screen.dart`
- `lib/features/guardian/presentation/guided_report_screen.dart`
- `lib/features/volunteer/data/api_volunteer_repository.dart`
- `lib/features/volunteer/data/volunteer_auth_service.dart`
- `lib/features/volunteer/data/volunteer_push_service.dart`
- `lib/features/volunteer/domain/volunteer_models.dart`
- `lib/features/volunteer/presentation/volunteer_capture.dart`
- `lib/features/volunteer/presentation/volunteer_case_views.dart`
- `lib/features/volunteer/presentation/volunteer_components.dart`
- `lib/features/volunteer/presentation/volunteer_entry.dart`
- `lib/features/volunteer/presentation/volunteer_identification_views.dart`
- `lib/features/volunteer/presentation/volunteer_workspace.dart`
- `test/api_volunteer_repository_test.dart`
- `test/guardian_flow_test.dart`
- `test/volunteer_retention_api_test.dart`
- `test/volunteer_shared_auth_test.dart`
