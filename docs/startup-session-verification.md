# Startup/session routing fix ? 2026-09-14

## Root cause
Splash used auth.signedIn as a direct choice between /guardian and Language Selection. Firebase currentUser only indicates a persisted identity, not a verified Guardian role/profile. GuardianGate then attempted profile loading and exposed a generic failure. Logout explicitly cleared navigation to /auth. Volunteer selection had no login destination.

## Current implementation
- AppRouter remains the only router; initialRoute remains AppRoutes.root.
- Splash retains its UI/timing, then replaces itself with /session.
- Session resolution waits for Firebase authStateChanges' initial state.
- Signed out: Language Selection (saved locale retained) -> Role Selection -> chosen authentication screen. Locale never selects a role.
- Signed in: authenticated GET /v1/session resolves users/{uid}.role, checking compatible token claims. Unknown/admin/conflicting roles are rejected.
- Guardian: only after successful real profile retrieval does navigation enter /guardian.
- Volunteer: never loads Guardian data. /auth/volunteer is reachable and uses real Firebase login without self-registration. This branch has no Volunteer workspace; a verified Volunteer session receives a controlled unavailable-destination state.
- Missing profile: explicit Guardian completion is available; after Guardian login a missing profile opens completion directly. It saves under the existing UID and never calls Firebase createUser again.
- Backend unavailable/expired/unresolved: controlled Account recovery with retry, role selection and sign-out. No automatic logout and no forced Guardian Login loop.
- Logout clears protected history to Language Selection, retaining locale.
- API timeout includes token acquisition, connection and response.
- Production lib/ contains no test-profile values or fixture imports.

## Files changed in this pass
Created:
- lib/features/auth/presentation/session_screen.dart
- test/session_startup_test.dart
- docs/startup-session-verification.md

Updated:
- lib/core/routing/app_routes.dart and app_router.dart
- lib/features/onboarding/presentation/screens/splash_screen.dart and role_selection_screen.dart
- lib/features/auth/data/auth_service.dart and presentation/auth_screen.dart
- lib/features/guardian/data/guardian_repository.dart and guardian_api.dart
- lib/features/guardian/presentation/guardian_gate.dart and guardian_home_screen.dart
- lib/shared/widgets/feature_page.dart
- English/Arabic ARBs and generated localization files
- test/support/guardian_fakes.dart, guardian_flow_test.dart, language_selection_screen_test.dart
- backend/app/main.py, service.py, tests/test_crud.py, tests/test_guardian.py
- backend/README.md

No new packages. No Firebase configuration, Gradle, SDK/NDK, applicationId, namespace or machine settings changed.

## Verification
- flutter pub get: passed.
- flutter gen-l10n / dart format: completed.
- flutter analyze: no issues.
- flutter test: 37 passed, including both locale cold-start branches, role resolution, Volunteer isolation, unavailable-session recovery, retry, partial-account save without duplicate registration, logout history and stale results after sign-out.
- Backend pytest: 13 passed; two upstream Starlette/AnyIO deprecation warnings.
- FastAPI app.main:app restarted on existing port 8000.
- Host GET /health: 200 {status: ok}.
- GET /v1/session without bearer: 401.
- Diagnostic bearer request: 503 at Admin initialization.
- Credential diagnostic: DefaultCredentialsError: Your default credentials were not found.
- Central emulator API URL: http://10.0.2.2:8000.
- Normal lib/main.dart Android APK built and installed. Flutter engine started.
- Android runtime inspection could not complete: emulator-5554 remains listed as device, but shell and screencap commands repeatedly timed out, including a simple echo. No emulator/system workaround was applied.
- Direct emulator HTTP probe did not yield a response and subsequently timed out. Emulator-to-backend reachability is NOT claimed as verified in this pass.
- Real existing-account repair, new signup, login, persisted name/email/phone, and signed-in Home relaunch remain unverified. Tests use isolated fixtures only and do not prove live persistence.
- No test-only entry point was run during this pass. No existing Firebase user was deleted or duplicated.
- The intended signed-out live test was not executed because Android controls stopped responding before sign-out. The saved session has not been deliberately cleared.
- This is a code/test completion report, NOT certification of the requested live production flow.

## External Firebase setup
Provide valid Application Default Credentials to the existing FastAPI process for project radd-32eb6, with appropriate Firestore/Storage access, and restart that process. Keep the credential file outside the repository:
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\radd-admin.json'
backend/.tools/python/python.exe -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000 --no-access-log
```
Use the actual protected credential path. This is process-scoped configuration, not a machine-level change. Once Android is responsive, rerun the normal-app live checks.
