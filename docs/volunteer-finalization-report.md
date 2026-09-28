# Volunteer correction pass — 2026-09-28

## Scope and outcome

This pass builds on the existing uncommitted assignment/location work. No Guardian UI, authentication model, assignment schema, Admin UI, cloud deployment, or real AI engine was introduced. No real account, assignment, registration, case, or found report was created/edited for testing. Prior working-tree changes were retained.

## Search participation

Both the case card and case-details action previously used `vStartSearch` unconditionally. The card separately selected outlined styling when the status was Search in Progress. Both now use the authoritative case status: Report Received → Start Search; Search in Progress → Join Search. Both use the same primary `VolunteerAction` style, icon, and busy/disabled handling. Joined users receive neither unjoined action.

The shared backend persists participation in `cases/{id}.joined_by`. Its public API exposes only the current user's `joined` / `confirmed_by_me` values; Flutter reconstructs its local participant set from these values after refresh/login. Available Cases excludes joined users; My Cases includes their searches and the confirming user's permitted subsequent workflow. Existing match confirmation removes access for other joined Volunteers. Join uses the existing Firestore transaction; only the first transition sets Search in Progress and creates the Guardian status notification. The transaction now clears its pending push intent on every retry so a retried transaction cannot reuse a first-start intent from an abandoned attempt.

## Manual Review

The authoritative data source remains `users` with `role == guardian`, followed by each Guardian's `individuals` subcollection filtered by `event_id == current Active Event`. Ownership, deletion, photo freshness, and existing active-case eligibility checks remain enforced on the backend. It does not require My Cases, any joined search, or an AI failure.

Two different causes were identified:

* Read-only inspection found 18 registration records, 17 associated with the current event. All 17 failed the existing photo freshness check. Missing authoritative `photo_captured_at` or a capture at least 24 hours old fails that check. This is a data eligibility issue, not permission to remove the event/freshness filters. No timestamps or photos were rewritten.
* Flutter re-filtered the authoritative registration list using its independently refreshed case cache. That extra filtering has been removed for the API repository and Manual Review screen. A stale closed case cannot hide a registration that the server currently says is eligible.

Manual Review is removed from Home and is not a navigation tab. After the real photo/report workflow, the identification screen groups primary **Find Match with AI** and secondary **Manual Review**. Manual Review is also available while identification is processing; a recorded AI failure is not required. It retains name search, gender filtering, reset, and localized no-results states. An empty eligible registry has distinct wording rather than suggesting that resetting filters will create results.

Profile browsing does not itself confirm a match. Contact remains behind the existing authorized found-report/case context. The detail API now returns a derived `confirmation_available` flag; this is not a new Firestore field. Flutter fails closed if this field is absent, so the backend must be restarted with the current implementation before testing.

## AI and camera

Production camera capture, preview, retake/use, real found report upload, and photo cleanup remain in place; no gallery path was added. Identification UI distinguishes ready, processing, candidates, no reliable candidate, unavailable, and error. Errors have localized user wording and development diagnostics. The current backend still returns `state: unavailable` and no candidates.

The future response boundary accepts `state: no_reliable_candidate`, or `state: candidates` with entries `{person: <registration DTO>, similarity: <finite 0..1 number>}`. Supplied scores are sorted descending; invalid contracts fail rather than inventing values. No model was implemented and no real candidates/scores were generated. Selection still fetches authorized profile details and requires human confirmation.

## Standalone Found Report: deliberately unresolved finalization

A Found Report without a Guardian missing report remains a `found_reports` document. Creating it, browsing eligible profiles, selecting a profile, viewing information allowed by the owned report context, resuming the report, and ending the attempt remain available.

**No `cases` document is automatically created.** The previous `source=found_report` case creation branch was removed. If no applicable Guardian case exists, `confirm()` returns the internal `standalone_verification_pending` conflict without writing a match, a case, an individual active-case pointer, or notifications. Profile details show a localized explanation and do not offer a misleading confirmation action. The captured photo remains subject to the existing unfinished-report cleanup/end-attempt policy; it is not deleted on mere selection.

The exact dependency is `confirmed_case(report_id)`: verification and handover require `found_reports.case_id`, an authorized case whose `confirmed_by` is the Volunteer, and its matching `found_report_id`. QR validation/identifier fallback and Guardian-facing handover transitions use that case. A standalone verification identifier, Guardian presentation, authorization contract, and final status/statistics model have **not** been approved. They were not invented. Standalone match confirmation and final reunification therefore remain pending. Existing legacy source=found_report cases were not migrated or modified.

For a genuine existing Guardian missing-person case, the current flow remains Match Confirmed → Awaiting Guardian Verification → successful QR/identifier verification → explicit handover → Reunited. Verification alone does not reunite. Confirmed matches retain immediate found-photo deletion and notifications to other participants.

## Required location and participation

The workspace centralizes its event gate in `_canParticipate`: the authenticated API session must have an active account/current-event assignment and the location service must report granted permission plus enabled device services. Profile/ID/logout remain accessible for recovery. Initial missing access displays the localized required-location explanation and the appropriate permission or settings action before event content. Android permission labels and one-time permission behavior are not overridden.

Event list/history loading is deferred until the gate is satisfied. Restoring access triggers a refresh immediately. Permission/services loss closes protected camera/QR routes, dismisses foreground case notices, stops updates, and revokes the app's notification-registration eligibility. Event data remains protected behind the gate. Foreground notification handlers cannot open an event refresh while access is blocked.

A position stream creation failure previously fell into the same catch as permission denial. Stream failures now keep independently validated access, clear proximity coordinates, and recover via the existing heartbeat/resume path. Valid permission/services without a fix allow participation and standard alerts; stale, inaccurate, or invalid coordinates do not grant proximity. Position timestamps are checked, rather than treating an old delivered fix as newly captured.

Existing Android location foreground-service support is retained: it starts from a visible Activity only for assigned/active participation, with an ongoing localized notification. Logout, account loss, unassignment, event end, permission revocation, and disabled services stop access. Backend account/assignment checks remain authoritative; the server cannot attest Android permission state. Revocation detection still depends on notification/recovery and connectivity, not an instantaneous offline remote kill switch. Physical-device testing remains necessary.

The shared backend radius remains `PROXIMITY_RADIUS_METERS = 500`, supplied through the profile API. No UI-specific radius was added. Guardian coordinates become last-seen coordinates only when the existing `same_location` confirmation is true; standard alerts are not conditional on proximity.

## Files changed in this pass

* `backend/app/volunteer.py` — transaction retry push intent.
* `backend/app/volunteer_workflow.py` — confirmation availability and no synthetic missing case.
* `backend/tests/test_volunteer_workflow.py` — standalone no-write dependency and independent registration eligibility.
* `lib/features/volunteer/data/api_volunteer_repository.dart` — authoritative registry and AI boundary.
* `lib/features/volunteer/data/volunteer_location.dart` — fix failure recovery and timestamp validity.
* `lib/features/volunteer/domain/volunteer_models.dart` — confirmation capability.
* `lib/features/volunteer/presentation/volunteer_workspace.dart` — participation gate, restoration, identification state.
* `lib/features/volunteer/presentation/volunteer_case_views.dart` — Start/Join and Home entry removal.
* `lib/features/volunteer/presentation/volunteer_identification_views.dart` — Report entry/hierarchy, independent registry, pending standalone message.
* English/Arabic ARB and three regenerated localization Dart files.
* `test/api_volunteer_repository_test.dart`, `test/volunteer_assignment_test.dart`, `test/volunteer_location_test.dart`, `test/volunteer_manual_review_test.dart` — gate/restoration, transient stream failure, search/filter and placement regressions.
* New `test/volunteer_search_join_test.dart` and `test/volunteer_identification_contract_test.dart` — bilingual first/subsequent actions, coherent styling, stale-case independence, score validation, and no automatic confirmation.
* This report.

Earlier uncommitted files outside this list were preserved, not discarded.

## Validation and remaining manual checks

* Backend full suite: **184 passed**. Existing dependency deprecation warnings remain.
* Flutter full suite: **199 passed**, including Guardian, camera lifecycle, notifications, assignment, location, report/verification/handover and new regressions.
* `dart format`: completed on changed Dart files; localization regenerated.
* `flutter analyze`: **No issues found** after the style-only brace corrections.
* Android debug APK: built successfully with `RADD_API_URL=http://127.0.0.1:8000` for the existing ADB-forwarded local setup. Existing Kotlin plugin migration warnings remain.
* `git diff --check`: passed.

No live camera capture, QR handover, real two-Volunteer case mutation, or background push was performed as part of these tests. Automated fakes are isolated test fixtures, not application data.

Manual test with a separately confirmed TEST case: Saud starts Report Received; Lina sees Join Search on the same Search in Progress case; both see My Cases; confirming one match removes the other's access. Verify fresh login/resume reconstructs this state. Use a fresh eligible TEST registration photograph before testing Manual Review. Test location denial, one-time permission expiration, services off/on, temporary unavailable fix, background notification/service, unassignment/deactivation/event end, and logout on Android. Test real camera retake/use and a genuine Guardian QR/identifier followed by explicit handover only for a confirmed test case. Standalone final handover remains intentionally unavailable.

No commit, push, deployment, Admin UI, or AI model implementation.

The local Uvicorn process was restarted on the same `127.0.0.1:8000` endpoint with current code. No additional maintenance job was enabled. The new debug APK was built, not installed onto the emulator by this pass. Use the current Flutter build/hot restart before manual testing.
