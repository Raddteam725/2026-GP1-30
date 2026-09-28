# Volunteer assignment implementation report

## Completed in this phase

- Approved existence-based `events/{eventId}/volunteers/{uid}` assignment,
  independent of `users.active`; no automatic real-user assignments.
- Central backend event authorization for queries, mutations, private profile
  data and queued notification delivery, including an event-switch race check.
- Shared `VolunteerManagement.change` operations and an ADC operator CLI that
  previews unless `--apply` is supplied. No Admin UI or public management API.
- Assignment-aware Flutter repository, protected data clearing, route dismissal
  on access loss, and current-event Digital ID separate from account status.
- Authorized Android location foreground service wired into participation;
  stop on detected revocation/logout/permission loss/service disable; temporary
  missing estimates retain participation. Existing 500m shared configuration.
- Non-sensitive foreground access-change hints plus existing 20-second/resume
  recovery. Backend checks are authoritative; offline client detection is not
  instantaneous. See the guide for Android process/lifecycle limitations.
- Preserved AI-first/independent Manual Review, camera, reports, Guardian contact
  restrictions, QR/alternative verification, handover, localization and Guardian.

## Verification

- `dart format` on changed Dart sources/tests: completed.
- `flutter gen-l10n`: completed from bilingual ARB sources.
- `flutter analyze`: no issues.
- `flutter test`: **193 passed**.
- `backend/.venv/bin/python -m pytest backend/tests -q`: **173 passed**.
- `flutter build apk --debug`: succeeded; `build/app/outputs/flutter-apk/app-debug.apk`.
- `backend/.venv/bin/python backend/scripts/manage_volunteer.py --help`: succeeded.
- `git diff --check`: clean.

Existing SDK dependency deprecation warnings remain (backend dependencies/FCM
Message.token and Android plugin Kotlin migration warnings). No dependencies
were upgraded solely to silence warnings.

No live Firebase mutations, ADC changes, deployment, commit or push were run.
Tests use isolated test fixtures, not production mock data. Device behavior and
real FCM delivery are not claimed as verified by these automated tests.

## Manual operations and remaining checks

See [the operation and device-test guide](volunteer-event-assignment.md) for
preview/apply commands for assign, remove, enable and deactivate, and the
complete test matrix. Existing test users must be explicitly assigned before
trying event functionality. Use the actual existing event ID, not a new event.

Physical Android testing is still required for persistent notification,
background location and priority alerts, assignment removal/event end during
participation, permission changes, logout and account reactivation. Actual AI
matching and the Sprint 5 Admin UI remain intentionally deferred. The future
Admin API can call the same business service after Admin authorization; the
Volunteer client contract does not need replacement.

## Working-tree files

The list below is the complete current uncommitted file set, including the
preserved earlier Manual Review/location changes. No unrelated work was reset.

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/drawable/ic_volunteer_location.xml`
- `backend/app/volunteer.py`
- `backend/app/volunteer_access.py`
- `backend/app/volunteer_alerts.py`
- `backend/app/volunteer_workflow.py`
- `backend/scripts/manage_volunteer.py`
- `backend/tests/test_volunteer.py`
- `backend/tests/test_volunteer_assignment.py`
- `backend/tests/test_volunteer_workflow.py`
- `docs/volunteer-assignment-implementation-report.md`
- `docs/volunteer-event-assignment-proposal.md`
- `docs/volunteer-event-assignment.md`
- `lib/core/localization/arb/app_ar.arb`
- `lib/core/localization/arb/app_en.arb`
- `lib/core/localization/generated/app_localizations.dart`
- `lib/core/localization/generated/app_localizations_ar.dart`
- `lib/core/localization/generated/app_localizations_en.dart`
- `lib/features/volunteer/data/api_volunteer_repository.dart`
- `lib/features/volunteer/data/mock_volunteer_repository.dart`
- `lib/features/volunteer/data/volunteer_location.dart`
- `lib/features/volunteer/data/volunteer_push_service.dart`
- `lib/features/volunteer/data/volunteer_repository.dart`
- `lib/features/volunteer/domain/volunteer_models.dart`
- `lib/features/volunteer/presentation/volunteer_account_views.dart`
- `lib/features/volunteer/presentation/volunteer_case_views.dart`
- `lib/features/volunteer/presentation/volunteer_identification_views.dart`
- `lib/features/volunteer/presentation/volunteer_workspace.dart`
- `test/api_volunteer_repository_test.dart`
- `test/api_volunteer_workflow_test.dart`
- `test/volunteer_assignment_test.dart`
- `test/volunteer_location_test.dart`
- `test/volunteer_manual_review_test.dart`
- `test/volunteer_merge_verification_test.dart`
- `test/volunteer_retention_api_test.dart`
