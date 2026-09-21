# Real-time diagnosis and controlled two-user test

Latest implementation, SDK timeout findings, test counts and live smoke-check results: [final real-time report](realtime-final-implementation.md). The findings below describe the earlier diagnostic stage; use the T0–T9 checklist with both updated builds. The final intended environment is one remotely accessible HTTPS backend, not a LAN requirement.

## Findings (2026-09-21)

The reported approximately two-minute observation remains a real, **unattributed** symptom: its case ID, exact time and Guardian backend address were not available. Do not assign it to another recent case or claim an end-to-end timing measurement that was not performed.

The current implementation uses FCM foreground/open listeners, a 20-second foreground reconciliation poll, and resume/entry refresh. It has no Volunteer Firestore snapshot listener. Notifications also have a legacy recovery/materialization path in `notifications_list()`: it creates missing new-case history from real active cases, but does not itself send FCM. Thus visible history is not proof of timely push delivery.

No 120-second application polling interval or timeout was found. The ID-token lookup and HTTP request each have a 30-second bound. The local maintenance loop waits 60 seconds *after* its jobs complete, and delivery leases last 60 seconds. These can contribute to retry latency, but do not establish the cause of the reported test. The diagnostic server was running with `RADD_LOCAL_JOBS=0`, so its maintenance retry loop was not running. Normal `backend/run_dev.py --adc` enables the approved local retention/retry jobs; the 24-hour retention condition is unchanged.

Read-only inspection found recent real new-case history without FCM delivery receipts, and recent resolved cases without a corresponding resolved history entry for the active Volunteer. That is consistent with actions not traversing the updated dispatcher or dispatch failing; the remote Guardian backend configuration cannot be inferred from the local checkout. No real case was changed to manufacture an event.

Existing correlated client/server logs show a verification request taking **26,324 ms client-side vs 1,214 ms server-side**, and a My Cases request taking **21,410 ms vs 969 ms**. Multiple requests reached the 30-second client timeout. The excess lies outside recorded backend route processing; the logs cannot distinguish all transport/connection scheduling causes. These measurements are not T0-to-popup measurements for Latifa's reported test.

## Changes

- Foreground events immediately show the existing localized, deduplicated banner and refresh only authenticated Available Cases, My Cases and notification history. They do not wait for profile, found reports, FCM registration or location. Reconciliation remains at 20 seconds; it was not accelerated.
- Event generations invalidate older refresh responses. Background refreshes do not start competing work while an event refresh is in progress.
- Open Case Details retains its case context. Authoritative cancelled/resolved/reunited/matched notification history replaces active-search content with the outcome and a Notifications action, rather than silently navigating away. Active lists still follow the backend response.
- Transient background errors preserve successful data and no longer produce global load-error banners over valid cases. Initial loading has a progress state, no false empty-state claim; an actual initial failure has a friendly retry. Critical action failures remain explicit and localized. Debug diagnostics remain available.
- Added timestamp/request/event correlation and previously missing FCM initialization, registration and send-failure diagnostics. No credentials or notification payload bodies are logged.

## Configure the two clients explicitly

Both Flutter roles use the compile-time `RADD_API_URL`. Its debug default, `http://10.0.2.2:8000`, means **the host of that particular Android emulator**. It does not mean Yara's Mac from Latifa's machine. `127.0.0.1` also means the current device unless an ADB reverse tunnel maps it. `run_dev.py` binds to `127.0.0.1` by default.

For a controlled test, use one known shared backend process running this current dispatcher code and the existing project `radd-32eb6`. Merely sharing Firebase does not make an older Guardian backend execute newer dispatch hooks.

- Lina's Pixel emulator currently uses `adb -s emulator-5554 reverse tcp:8000 tcp:8000` and an APK built with `--dart-define=RADD_API_URL=http://127.0.0.1:8000`.
- If Latifa uses a separate device on the same trusted LAN, that client must use the actual host Mac's LAN IP and port. The backend must deliberately be started with `--host 0.0.0.0` for LAN reachability, and the local firewall must allow it. Do not run a second server on the same port. This is a local debug arrangement, not a production deployment proposal. No LAN binding/firewall change was made automatically.
- If instead each developer runs a local backend, both must run the same current backend code, existing Firebase project/event configuration and appropriately configured Admin credentials. Record both backend logs; do not assume they are the same process.
- Rebuild/restart after changing `--dart-define`; hot reload does not change the endpoint. The first API request now logs the effective backend scheme/host/port in debug mode for both roles.

## Controlled create/cancel/resolve measurement

1. Verify clocks, effective backend addresses and updated code on both clients/servers. Keep the local backend logs and both Flutter debug logs. Do not copy credentials or tokens into the report.
2. Lina remains on Profile with a valid active session. Latifa performs one genuine case creation, recording the exact press time and resulting case ID. Do not navigate or manually refresh Lina's screen. Record popup time, then check history and Available Cases.
3. Lina joins that case and keeps Case Details open. Latifa cancels it. Record the same timestamps; confirm the popup, explicit Cancelled outcome on the existing screen, removal from active lists, and retained history.
4. Repeat resolution with a separate legitimate test workflow. Do not reuse a cancelled case or change its stored state manually. Confirm Person Found/Resolved with the same checks.
5. Read the stable event ID (`caseId-new`, `caseId-cancelled`, `caseId-resolved`) across logs. Duplicate receipt must not create duplicate popup/history rows.

| Stage | Evidence |
| --- | --- |
| T0 | User's exact press time; Guardian debug `T0` marks API invocation before token retrieval, not necessarily the button press |
| T1 | Backend request ID and receive epoch timestamp |
| T2 | Case transaction committed log with case/event ID |
| T3 | Durable notification history ready log |
| T4 | FCM send initiation |
| T5 | FCM accepted log and elapsed send duration; acceptance alone is not device delivery |
| T6 | Volunteer `Radd FCM ... received` and workspace event log |
| T7 | Immediate targeted refresh initiation |
| T8 | Targeted refresh completion, plus each API request's timing |
| T9 | Next UI frame after authoritative state publication |

Compare adjacent timestamps. If T2 exists but T3/T4 do not, inspect the dispatcher and eligibility/failure logs on the **backend receiving Guardian's request**. If T5 exists but T6 does not, inspect device/FCM delivery and session registration. If T6 is prompt but T8 is late, compare request client/server timings. Do not infer FCM receipt from history discovered on a poll.

## Validation and remaining work

`flutter analyze`: no issues. Full Flutter suite: **144 passed**. Full backend suite: **153 passed**, 47 upstream deprecation warnings. Coverage includes foreground banners, targeted refresh without profile/report requests, cancellation/resolution while details remains open, duplicate suppression, transient-failure preservation, initial loading, and existing stale-response/authorization regressions. These are automated isolated tests, not a fabricated live demonstration.

The instrumented debug APK was built and installed on Pixel 7 with the existing session preserved. The shared local backend was restarted with the new logs and existing ADC. Real authenticated list/report/device-registration requests returned HTTP 200; observed backend registration durations were 414–660 ms and a found-report list took 1,063 ms. Those are individual route timings, not two-user event latency. Local diagnostic logs are `/tmp/radd-event-live.log` and `/tmp/radd-event-instrumented-device.log`.

The controlled three-event two-user measurement is still pending Latifa's availability. No post-fix live T0–T9 latency is claimed. No AI functionality, Guardian UI, retention condition, authentication rule, production deployment, commit or push was introduced.
