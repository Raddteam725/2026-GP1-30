# Radd real-time implementation — 2026-09-21

This report supersedes earlier test counts in `volunteer-realtime-report.md` and `realtime-controlled-test.md`. Existing uncommitted changes were retained. No deployment, commit, push, AI engine, authentication bypass, or synthetic production case was introduced.

## Causes established by code inspection

- The installed Firebase Admin HTTP client defaults to a 120-second timeout. FCM and notification-related Auth lookups previously ran synchronously in the business request. Slow notification transport could therefore delay the response after its case transaction had already committed.
- Guardian foreground listeners were installed after permission/token/registration work. Home, Cases and QR did not all subscribe to the event refresh signal. Guardian registrations did not retain the verified session expiry/authentication time, and Guardian delivery lacked durable per-device receipts and a maintenance retry path.
- Earlier fixes retained in this tree address Volunteer refreshes coupled to registration/photo loading, lost refresh signals, transient errors clearing good data, and stale responses overwriting newer data.
- No 120-second application poll was found. Volunteer reconciliation is 20 seconds; Guardian case-detail recovery is 8 seconds; maintenance and delivery leases are 60 seconds. These are recovery mechanisms, not the normal event path.

The reported two-minute two-user delay is **not conclusively attributed**: the original case ID, timestamps and Latifa's backend URL were unavailable. Earlier correlated logs demonstrated transport delay as well (26,324 ms client-side versus 1,214 ms server-side on one request). Those are individual request measurements, not end-to-end notification latency.

## Implemented flows

Guardian create/cancel/resolve → authorized Firestore commit → durable recipient notification → immediate bounded local worker → session eligibility recheck → FCM → Volunteer global deduplicated banner → authenticated FastAPI state/list/history refresh → current screen update.

Volunteer first join/confirmed match/begin verification/verified handover → authorized transaction and Guardian notification → immediate worker → FCM → Guardian refresh signal → subscribed Home, Cases, Case Status, QR case context and Notifications refetch their authoritative data. Later joins do not emit a false second status transition. QR verification and handover requirements are unchanged.

The new `/v1/volunteer/cases/{case_id}/state` returns only ID/status. It checks Active Volunteer, current event, visibility or previous participation/notification, scrub state and the existing 24-hour retention boundary. It does not grant closed-case private-detail access. Open Volunteer details show the authoritative Cancelled/Resolved/Reunited outcome; history remains visible while active lists update.

Foreground banners remain dismissible, global, localized and deduplicated by stable event ID. Background delivery uses FCM system notifications. Notification actions retain authenticated routing. FCM is a signal, not a trusted replacement for backend state.

## Delivery, security and recovery

`delivery_queue.py` starts an immediate attempt on one of four local workers, with a bounded 256-item queue and duplicate coalescing. Slow sends no longer hold the business response. Firestore remains the durable retry source; queue-full/process-exit/send failures do not create successful receipts. Existing leases and per-device receipts suppress ordinary duplicate attempts. A crash after FCM acceptance but before receipt persistence can still cause redelivery; clients deduplicate stable IDs.

Both role registrations store verified token expiry/auth_time. ID-token renewal renews registration; FCM token rotation and re-login re-register. Send workers recheck expiry, role/account eligibility, Firebase disablement/revocation and current registration. Volunteer event assignment is rechecked as well. Logout cancels listeners, unregisters and requests deletion of the installation token; an upload finishing after logout is cleaned up. Already accepted/displayed OS notifications cannot be recalled. When offline, immediate server confirmation of logout cannot be guaranteed; expiry/revocation checks remain enforced, never bypassed.

Admin `httpTimeout` is explicitly 5 seconds per SDK HTTP attempt. The outer Auth retry loop stops initiating additional retries after 8 elapsed seconds. **Neither is a total request deadline:** SDK retries, credential refresh and Firestore transport have independent behavior. Auth revocation checking stays enabled.

The approved local maintenance loop now retries Guardian as well as Volunteer notifications. It runs its checks at 60-second intervals after job completion; it does not delete data before the existing 24-hour eligibility condition. Normal delivery does not wait for this loop. Resume triggers immediate recovery. Transient refresh failures preserve good state, log diagnostics in development, and do not pretend critical actions succeeded.

## Files edited for this final architecture pass

Backend:

- `backend/app/delivery_queue.py` — new immediate local dispatcher.
- `backend/app/firebase.py` — explicit SDK timeout and bounded outer Auth retries.
- `backend/app/push.py` — durable Guardian notification/receipts, worker delivery, eligibility and retries.
- `backend/app/volunteer_alerts.py` — queued send, fresh session/event checks and receipts.
- `backend/app/service.py` — Guardian registration session association.
- `backend/app/local_jobs.py` — Guardian recovery job.
- `backend/app/volunteer.py` — minimal authorized case-state endpoint and commit timing.
- `backend/app/volunteer_workflow.py` — Volunteer status-commit timing.

Flutter:

- `lib/features/guardian/data/guardian_push_service.dart` — early listeners, event deduplication, token renewal, resume signal, logout/race handling and diagnostics.
- `lib/features/guardian/presentation/guardian_gate.dart` — authenticated notification-tap routing.
- `lib/features/guardian/presentation/guardian_home_screen.dart`, `cases_screen.dart`, `notifications_screen.dart`, `guardian_qr_screen.dart` — event refresh subscriptions, stale-response guards, preserved data.
- `lib/features/volunteer/data/api_volunteer_repository.dart` — event-specific authoritative case-state refresh and action timing.
- `lib/features/volunteer/presentation/volunteer_workspace.dart` — request affected state and render closure outcome.

Tests:

- `backend/tests/conftest.py`, `test_immediate_delivery.py`, `test_volunteer_alert_delivery.py`, `test_fcm.py`, `test_cases.py`, `test_local_jobs.py`, `test_volunteer.py`.
- `test/guardian_push_service_test.dart`, `test/guardian_flow_test.dart`, `test/api_volunteer_repository_test.dart`.

Existing uncommitted event/banner/session-binding, localization, transport diagnostics and Guardian-aligned Volunteer UI changes from preceding work were preserved. They remain visible in `git diff`; they were not all newly authored in this pass. Guardian visual design was not changed by this pass.

## Verification

- `flutter analyze` — no issues.
- Full `flutter test` — 148 passed.
- `backend/.venv/bin/python -m pytest backend/tests -q` — 160 passed; 47 upstream deprecation warnings.
- Regression coverage includes durable-before-send, immediate nonblocking worker execution, bounded queue, send-time logout eligibility, Guardian expired/revoked sessions, foreground deduplication, targeted refetch, open-case cancellation/resolution, minimal closed-state authorization/retention, resume recovery, Guardian Home/Cases refresh, stale responses and preservation of valid data. Existing camera/manual review/QR/handover/auth tests remain included.
- Automated tests use isolated test doubles; they are not proof of live FCM delivery or the two-user latency target.
- Debug APK build and installation on Pixel 7 succeeded with existing app data/session preserved. The updated local backend was restarted with existing ADC. The real authenticated Available Cases, My Cases, notification history, found reports, photos and FCM-registration routes returned HTTP 200. Observed server durations included Available Cases 519 ms, My Cases 721 ms, history 645 ms and FCM registration 499–634 ms. These are individual route timings, not two-user event latency. Logs: `/tmp/radd-final-live.log` and `/tmp/radd-final-device.log`.
- `git diff --check` passed; there are no unmerged paths. No real case was created, cancelled, resolved, joined or handed over during this verification. The running diagnostic backend retains `RADD_LOCAL_JOBS=0` to avoid executing retention deletion as a test. For normal approved local operation, `backend/run_dev.py --adc` enables the 60-second maintenance loop; the immediate delivery worker operates independently of that setting.

## Controlled live test still required

Use the checklist in `realtime-controlled-test.md` with both updated apps and a known backend configuration. Record T0 action invocation, T1 request arrival, T2 commit, T3 history, T4 send, T5 acceptance/failure, T6 FCM receipt, T7 fetch start, T8 completion and T9 UI frame. Case/event IDs correlate logs without printing tokens, photographs, QR payloads or contact details.

Test create while Volunteer is on Profile; cancel/resolve while Volunteer details remains open; first join and subsequent verification/handover updates while Guardian screens remain open. Also test background/terminated notification taps, duplicate delivery, a normal ID-token refresh boundary, logout/re-login and temporary offline recovery. Do not infer immediate delivery from history discovered by polling. No fresh two-user T0–T9 latency is claimed in this report.

## Separate Cloud Run step

The authoritative API/Firestore/FCM design is compatible with a shared HTTPS backend used from independent networks. `RADD_API_URL` remains configurable; local emulator addresses are not release defaults.

**The current local worker is not deployment-ready Cloud Run infrastructure.** A separate deployment change must replace in-process delivery with reliable managed execution (including durable enqueue recovery), move maintenance to an authenticated managed scheduler/job, configure PORT/listening/container settings and runtime IAM/ADC, and verify retry/deduplication under instance shutdown/scaling. Request-billed Cloud Run must not be assumed to keep background daemon threads running after a response. No deployment or cloud configuration was performed.
