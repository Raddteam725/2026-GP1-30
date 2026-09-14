# Guardian Sprint 0 verification ? 2026-09-14

Working copy: C:\GitHub\Radd. Existing Firebase/native configuration and Git branch were preserved.

## Implementation
- Existing router, theme and locale scope extended; no second application architecture.
- Firebase Auth login, registration, reset and logout; partial registration can retry profile completion.
- Guardian profile, individual list/add/detail/edit/delete, camera-only photo flow, and protected routes use repository interfaces backed by FastAPI in production.
- Exactly five Guardian tabs. QR, Cases and notifications show localized later-sprint feedback without operational records.
- Shared page padding 24 dp, content maximum 480 dp, rounded panels, consistent 8/12/16/24 spacing, minimum 52 dp primary actions.
- Login branding/field icons, required red asterisks, separate photo/form panels, horizontal gender choices, profile information panels and destructive confirmations refined.
- Camera preview height is bounded with preserved aspect ratio. Capture has a 20-second timeout and retryable failure.
- Existing transparent assets/images/radd_logo_transparent.png retained. Existing staged splash and routing preserved.

## Files
Created during Guardian implementation:
- lib/app/app_services.dart
- lib/features/auth/data/auth_service.dart
- lib/features/auth/presentation/auth_screen.dart
- lib/features/auth/presentation/form_validation.dart
- lib/features/guardian/data/guardian_repository.dart
- lib/features/guardian/data/guardian_api.dart
- lib/features/guardian/presentation/guardian_components.dart
- lib/features/guardian/presentation/guardian_gate.dart
- lib/features/guardian/presentation/guardian_home_screen.dart
- lib/features/guardian/presentation/individual_widgets.dart
- lib/features/guardian/presentation/individual_form_screen.dart
- lib/features/guardian/presentation/individual_profile_screen.dart
- lib/features/guardian/presentation/edit_guardian_profile_screen.dart
- lib/features/guardian/presentation/camera_screen.dart
- lib/shared/widgets/feature_page.dart
- backend/app/{__init__,main,firebase,models,service,cleanup}.py
- backend/tests/{test_guardian,test_crud}.py
- backend/requirements.txt, backend/requirements.lock, backend/README.md, backend/.gitignore
- test/guardian_flow_test.dart, test/guardian_runtime_app.dart, test/support/guardian_fakes.dart

Modified:
- lib/main.dart, lib/app/radd_app.dart, lib/app/app_locale_scope.dart
- lib/core/routing/app_router.dart, lib/core/routing/app_routes.dart
- lib/core/theme/app_theme.dart
- English/Arabic ARBs and generated localization files
- Existing splash/language/role screens and onboarding_selection_card.dart
- lib/shared/widgets/app_text_input.dart, lib/shared/widgets/password_input.dart
- pubspec.yaml, pubspec.lock and generated platform plugin registrants
- test/language_selection_screen_test.dart, test/splash_screen_test.dart

Existing native/Firebase dirty files and earlier onboarding implementation are not presented as newly authored in this pass.
Flutter dependencies added during Guardian implementation: firebase_auth, camera, http, shared_preferences. No integration_test dependency retained.

## Production data and security
Firebase ID token identifies the caller; backend verifies it and enforces Guardian role/ownership.
Profile: users/{uid}.
Individuals: users/{uid}/individuals/{id}.
Private photo objects: guardians/{uid}/individuals/{id}/{random}.jpg.
Photos are served through authenticated API calls, normalized to JPEG with orientation preserved and metadata removed. No public download URLs are created. Deferred cleanup is recorded for failed object deletion.
Profile email is taken from the verified Firebase token, not an editable field or fixture.
Cloud IAM/rules deployment was not performed.

## Verification actually run
- flutter pub get: passed.
- flutter gen-l10n: passed.
- dart format: completed.
- flutter analyze: no issues found.
- flutter test: 29 passed.
- Project-local Python pytest: 11 passed; two upstream Starlette/AnyIO deprecation warnings remain.
- Normal Android build/install/run using lib/main.dart: passed.
- Firebase initialized and restored the existing signed-in session. No new real account was created during this verification.
- Normal app runtime: no Flutter/AndroidRuntime exceptions in the filtered final logs; emulator graphics/skipped-frame warnings and Firebase plugin future-Kotlin compatibility warning remain.
- English Home/Add/Profile and Arabic Profile/Login/logout dialog were visually inspected on the emulator; language switching and five-tab mirroring observed. Widget tests cover onboarding navigation, form validation, large text in both languages, locale switching, protected history and isolated CRUD.
- Visual fixture testing was explicitly labelled UI TEST - NO CLOUD and required an opt-in define. Normal lib/main.dart has been restored on the emulator. No test fixture imports or test-profile values occur in lib/.
- The earlier wrong email was from the test-only repository, not Firebase. Test-only editing did not establish cloud persistence.
- Camera opened, with the emulator's corrupted striped source. A capture request did not return; capture/use/retake cannot be certified on this emulator. User also observed corruption in the emulator's own Camera app. No emulator/system changes made.
- Live profile/Firestore/Storage CRUD NOT verified: Admin credentials unavailable. API health responds, but health is only liveness and does not prove Firebase access.
- Full live visual/data parity is therefore not claimed.

## Required external setup action
Start the existing FastAPI backend with valid Application Default Credentials for Firebase project radd-32eb6 (with the required Firestore/Storage access). Keep the credential file outside the repository. For example, in the backend terminal only:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\radd-admin.json'
backend/.tools/python/python.exe -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000 --no-access-log
```

Replace the example path with the actual protected credential file and restart the current server with that process environment. This is not a machine-level environment change. Then retry the normal app and complete live persistence checks.
Exact diagnosed error: DefaultCredentialsError: Your default credentials were not found.
