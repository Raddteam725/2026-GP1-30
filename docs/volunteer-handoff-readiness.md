# Volunteer branch handoff readiness — 2026-09-29

## Focused continuation fix

The old `_resumeReport()` chose a screen from `matchedPerson` / verification
presence and the Missing Case-style status rather than the stored Found Report
lifecycle. Awaiting verification returned to contact, and absent profile content
fell back to identification. Background/resume refresh replaced repository lists
but left the open workflow's report object and navigation stale. Confirmation also
left earlier Manual Review/profile screens reachable through Back.

The continuation destination now follows authoritative FoundStatus:

| Stored state | Destination |
| --- | --- |
| identification_in_progress | Identification; AI remains unavailable, Manual Review remains accessible |
| identity_confirmed | Guardian Contact |
| awaiting_guardian_verification | QR / real Found Report identifier verification; an existing valid server receipt resumes the verified/handover stage |
| reunited | Completed, with no identification restart |

Missing required identified-profile data fails closed instead of reopening Manual
Review. Resuming clears stale identification routes. Explicit confirmation removes
old Manual Review/profile routes from Back. The active workflow reloads its report
on the existing refresh/app-resume path and changes destination when its stored
lifecycle/proof changes. Independent Manual Review browsing is not overwritten by
an unrelated previously opened report.

No Missing Case is created or required. No AI, consent, location, assignment,
retention, notification or Guardian architecture was redesigned.

Changed in this final pass:

- `lib/features/volunteer/presentation/volunteer_identification_views.dart`
- `lib/features/volunteer/presentation/volunteer_workspace.dart`
- `test/volunteer_found_continuation_test.dart` (new, eight bilingual lifecycle tests)
- `test/volunteer_manual_only_test.dart` (Back must return to Report, not old identification)
- `backend/tests/test_volunteer_workflow.py` (fresh-service standalone restore before verification and after completion)
- this handoff report

## Read-only live audit

Existing ADC; project `radd-32eb6`. Only two Firestore document reads were made.
`test123` exists and links to `FR-2b6e7a21402fd4f5b06012df4afbfffb7b738545`.
The report is `awaiting_guardian_verification`, `case_id: null`, `ended: false`,
has no recorded Guardian verification and no Found photo path. Event:
`C8fES02usly6UXgMh6sl`.

No reset, duplicate report, verification, handover, consent write, assignment change
or Firebase cleanup was performed. No emulator interaction was performed.

## Validation

- Full Flutter suite: 222 passed.
- Full backend suite: 233 passed (56 existing SDK/deprecation warnings).
- Flutter analyze: no issues.
- Changed Dart files formatted; git diff --check passed.
- Android debug build succeeded; existing Kotlin migration advisory remains.
- No unresolved merge paths or conflict markers.

The debug build retains `RADD_API_URL=http://127.0.0.1:8000` for the existing local
development setup (adb reverse required). The APK was not installed. Restart the
backend with the current code before controlled testing; the build does not update
an already-running backend process.

## Pending controlled live tests (not code-handoff blockers)

The user should accept current consent through the app, satisfy location requirements,
and resume the existing test123 report from Report. It should open verification
without another identity confirmation. The associated Guardian opens the real QR
or Found Report identifier in their authenticated app. Test verification and explicit
handover under user control; do not create a replacement report. Backend QR/identifier verification and final Reunited transition were covered by
isolated automated tests, not performed on this real report. Actual QR scanning
remains a controlled device test.

Previously identified physical-device checks remain: background FCM and tap routing,
background location stop/recovery, and real camera behavior. No claim of new live
verification of those platform behaviors is made here.

## Repository review and exact commit manifest

Branch: `volunteer`. At review, HEAD and locally fetched `origin/volunteer` have
0/0 unique commits; no fetch/pull/merge/rebase was performed. Nothing is staged.
No commit or push was performed. All earlier uncommitted implementation was preserved.

Final status: **52 modified tracked files, 39 untracked files, 0 staged, 0 deleted, 0 unmerged**.

The following is the exact intended file manifest for the user's commit. It includes
approved earlier work, not just this final continuation fix. Generated localization
Dart files are already tracked project outputs and belong with their ARB sources.
Android notification/location resource files are application source, not emulator
artifacts.

```text
 M android/app/src/main/AndroidManifest.xml
 M android/app/src/main/kotlin/com/example/radd/MainActivity.kt
 M backend/README.md
 M backend/app/cases.py
 M backend/app/cleanup.py
 M backend/app/main.py
 M backend/app/models.py
 M backend/app/service.py
 M backend/app/volunteer.py
 M backend/app/volunteer_alerts.py
 M backend/app/volunteer_workflow.py
 M backend/scripts/provision_volunteer.py
 M backend/tests/firestore_fake.py
 M backend/tests/test_cases.py
 M backend/tests/test_crud.py
 M backend/tests/test_fcm.py
 M backend/tests/test_guardian.py
 M backend/tests/test_retention.py
 M backend/tests/test_volunteer.py
 M backend/tests/test_volunteer_alert_delivery.py
 M backend/tests/test_volunteer_workflow.py
 M lib/core/localization/arb/app_ar.arb
 M lib/core/localization/arb/app_en.arb
 M lib/core/localization/generated/app_localizations.dart
 M lib/core/localization/generated/app_localizations_ar.dart
 M lib/core/localization/generated/app_localizations_en.dart
 M lib/features/auth/presentation/session_screen.dart
 M lib/features/guardian/data/guardian_api.dart
 M lib/features/guardian/data/guardian_repository.dart
 M lib/features/guardian/presentation/case_widgets.dart
 M lib/features/guardian/presentation/guardian_qr_screen.dart
 M lib/features/guardian/presentation/individual_form_screen.dart
 M lib/features/volunteer/data/api_volunteer_repository.dart
 M lib/features/volunteer/data/mock_volunteer_repository.dart
 M lib/features/volunteer/data/volunteer_location.dart
 M lib/features/volunteer/data/volunteer_push_service.dart
 M lib/features/volunteer/data/volunteer_repository.dart
 M lib/features/volunteer/domain/volunteer_models.dart
 M lib/features/volunteer/presentation/volunteer_account_views.dart
 M lib/features/volunteer/presentation/volunteer_case_views.dart
 M lib/features/volunteer/presentation/volunteer_entry.dart
 M lib/features/volunteer/presentation/volunteer_identification_views.dart
 M lib/features/volunteer/presentation/volunteer_workspace.dart
 M test/api_volunteer_repository_test.dart
 M test/api_volunteer_workflow_test.dart
 M test/guardian_flow_test.dart
 M test/session_startup_test.dart
 M test/support/guardian_fakes.dart
 M test/volunteer_design_test.dart
 M test/volunteer_location_test.dart
 M test/volunteer_merge_verification_test.dart
 M test/volunteer_retention_api_test.dart
?? android/app/src/main/res/drawable/ic_volunteer_location.xml
?? android/app/src/main/res/values-ar/strings.xml
?? android/app/src/main/res/values/strings.xml
?? backend/app/found_reports.py
?? backend/app/registration_retention.py
?? backend/app/volunteer_access.py
?? backend/app/volunteer_consent.py
?? backend/scripts/configure_registration_periods.py
?? backend/scripts/create_test_volunteer.py
?? backend/scripts/manage_volunteer.py
?? backend/tests/test_registration_retention.py
?? backend/tests/test_test_volunteer_provisioning.py
?? backend/tests/test_volunteer_assignment.py
?? backend/tests/test_volunteer_consent.py
?? docs/manual-confirmation-live-diagnosis.md
?? docs/registration-retention.md
?? docs/standalone-found-reports.md
?? docs/volunteer-assignment-implementation-report.md
?? docs/volunteer-consent-implementation.md
?? docs/volunteer-event-assignment-proposal.md
?? docs/volunteer-event-assignment.md
?? docs/volunteer-finalization-report.md
?? docs/volunteer-handoff-readiness.md
?? docs/volunteer-notification-location-corrections.md
?? docs/volunteer-stabilization-final-report.md
?? docs/volunteer-terms-privacy-drafts.md
?? lib/features/volunteer/data/volunteer_notification_memory.dart
?? lib/features/volunteer/presentation/volunteer_consent_screen.dart
?? test/standalone_found_report_api_test.dart
?? test/volunteer_assignment_test.dart
?? test/volunteer_capture_manual_review_test.dart
?? test/volunteer_consent_test.dart
?? test/volunteer_found_continuation_test.dart
?? test/volunteer_identification_contract_test.dart
?? test/volunteer_location_gate_test.dart
?? test/volunteer_manual_only_test.dart
?? test/volunteer_manual_review_test.dart
?? test/volunteer_notification_memory_test.dart
?? test/volunteer_search_join_test.dart
```

## Exclude from commits

Do not add `.env` / local environment files, ADC or private credentials, service-account
keys, `backend/.venv/`, `.dart_tool/`, build/APK/AAB outputs, Android local.properties,
local logs, `/tmp` audit/test logs, editor session state or emulator data/configuration.
The current intended manifest contains none of these. Existing ignore rules cover the
present local virtual environment, APK and Android SDK-local configuration.

A read-only scan of tracked and nonignored candidate text files found no private-key
blocks, service-account JSON credentials, OAuth refresh-token literals or unresolved
merge markers. Filename review found no local environment/credential/build artifact
candidates. Firebase client configuration already tracked in the project is not a
Firebase Admin private credential and was not modified in this pass. No private
values were printed during the review.
