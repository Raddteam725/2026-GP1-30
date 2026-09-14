# Volunteer integration

The real Volunteer entry now authenticates with the existing Firebase Auth instance and obtains its admin-managed profile from the existing FastAPI server. It instantiates `ApiVolunteerRepository`, never `MockVolunteerRepository`. Guardian screens, Guardian services, Firebase configuration, onboarding and routing are unchanged.

## Firestore

- Existing project: `radd-32eb6`; the existing Admin SDK configuration and Storage bucket are reused.
- `users/{firebase_auth_uid}`: admin-provisioned `role: "volunteer"`, `full_name`, `email`, `phone`, `volunteer_id`, boolean `active`, `created_at`, `updated_at`. Admin provisioning must use server timestamps; there is no mobile account creation/update endpoint and no passwords stored in these documents. Firebase Auth must already contain the corresponding account. Legacy `enabled`/`volunteerId` custom claims are not required for the new Volunteer endpoints. Conflicting token roles are rejected.
- Existing `cases/{caseId}`: same Guardian-created records, including `guardian_id`, `individual_id`, `event_id`, case details and timestamps. Joining adds `joined_by` and changes `report_received` to `search_in_progress` only once, using server timestamps. The document, active event and Volunteer account are read within a Firestore transaction, so concurrent joins retry rather than overwrite participation. Further joins preserve the existing status timestamps and `updated_at`.
- Existing `events/{eventId}`: exactly one active event is required, using the shared event resolver. Cases from other events are not exposed.
- Existing registration and photo storage are read through their case relationship. No duplicate `volunteer_cases`, database, backend, photos or Guardian registrations are created.
- `confirmed_by` is read for visibility after a future matching service has advanced the shared case. Only that Volunteer retains a matched/verification/reunited case in My Cases. This change does not invent a match-confirmation write endpoint.

## Endpoints

All use the verified Firebase ID token from `Authorization: Bearer ...`; request bodies never select the acting UID.

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/v1/volunteer` | Firestore profile for the authenticated Volunteer; inactive accounts may display their real ID/profile |
| GET | `/v1/volunteer/cases/available` | Active account, current event, joinable cases not joined by this UID |
| GET | `/v1/volunteer/cases/mine` | Active account, joined open cases or cases confirmed by this UID |
| POST | `/v1/volunteer/cases/{case_id}/start-search` | Transactional, idempotent joining; no client UID/status/timestamp accepted |
| GET | `/v1/volunteer/cases/{case_id}/photo` | Authorized private JPEG bytes for a visible case; no public URL/private Storage path returned |

Responses expose only the current user's participation/confirmation booleans, not other Volunteer UIDs or Guardian contact information. Guardian APIs continue reading status from the same shared case document.

## Flutter behavior

Home, Available Cases, My Cases, Profile and Digital ID read API data. Start Search updates the displayed case immediately from the server response. Profile and cases refresh on opening the workspace, returning to the foreground, and every 20 seconds while foregrounded. An older in-flight list refresh is awaited before joining, preventing it from overwriting that response locally. Admin deactivation clears cases and changes the ID to inactive. Data refresh errors clear stale case lists, display localized feedback and offer retry. Photos are held in memory for the current repository and are never replaced with sample photos on error.

Existing screen layouts and preview workflows are preserved. This is foreground polling, not Firestore streaming or push notifications. The existing GPS/proximity calculation can use real guided-report coordinates only when the Guardian confirmed the last-seen location.

## Intentionally future work

Real found-person capture/submission, AI matching, manual matching, Confirm Match, Guardian contact, QR verification, handover and Volunteer push notifications remain unsupported. Real-account operations for these workflows fail closed; they do not write sample reports, fabricate AI results, accept preview QR payloads, or mark anyone reunited. `MockVolunteerRepository` remains limited to explicit debug preview and tests. The backend still has the existing Guardian QR issuance endpoint; Volunteer QR consumption is not added here.

## Run locally (macOS, from repository root)

Use the existing authorized Application Default Credentials environment, outside the repository. No new Firebase configuration is necessary. Provision the Volunteer account through the admin process described above; do not sign up through Guardian to create a Volunteer. A Guardian must report a real case for it to appear in Available Cases.

```sh
cd /Users/yara/Desktop/Radd
backend/.venv/bin/python -m pip install -r backend/requirements.txt
backend/.venv/bin/python -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000 --reload
```

In a second terminal, with an Android emulator running:

```sh
cd /Users/yara/Desktop/Radd
flutter pub get
flutter gen-l10n
flutter run --dart-define=RADD_API_URL=http://10.0.2.2:8000
```

Release builds must specify the shared backend's HTTPS URL. A physical device cannot use the emulator-only `10.0.2.2` host.

Validation commands:

```sh
flutter gen-l10n
flutter analyze
flutter test
backend/.venv/bin/python -m pytest backend/tests
```

Backend tests use isolated Firestore/Storage fakes, including concurrent callers serialized by a test transaction adapter. They verify the application's transaction boundary; they are not a production Firestore contention/emulator test. No production accounts, cases or credentials were created for testing. A real-account device smoke test still requires your provisioned account and running authenticated backend.

## File inventory

Created:
- `backend/app/volunteer.py`
- `backend/tests/test_volunteer.py`
- `lib/features/volunteer/data/api_volunteer_repository.dart`
- `test/api_volunteer_repository_test.dart`
- `docs/volunteer-backend-integration.md`

Modified:
- `backend/app/main.py` (registers the new router only)
- `lib/features/volunteer/data/volunteer_auth_service.dart`
- `lib/features/volunteer/domain/volunteer_models.dart`
- `lib/features/volunteer/presentation/volunteer_entry.dart`
- `lib/features/volunteer/presentation/volunteer_workspace.dart`
- `lib/features/volunteer/presentation/volunteer_case_views.dart`
- `lib/features/volunteer/presentation/volunteer_components.dart`
- `lib/features/volunteer/presentation/volunteer_identification_views.dart`
- `lib/core/localization/arb/app_en.arb`
- `lib/core/localization/arb/app_ar.arb`
- `lib/core/localization/generated/app_localizations.dart`
- `lib/core/localization/generated/app_localizations_en.dart`
- `lib/core/localization/generated/app_localizations_ar.dart`

## Verification results

- `flutter gen-l10n`: passed; all pre-existing Arabic/English keys and values preserved.
- `flutter test`: 66 passed, including real-repository widget tests in both languages.
- `backend/.venv/bin/python -m pytest backend/tests`: 40 passed; two dependency deprecation warnings.
- `flutter analyze`: no errors or warnings; exits 1 because eight pre-existing informational brace-style lints remain (seven in Guardian `guided_report_screen.dart`, one in Volunteer `volunteer_location.dart`). Those files were deliberately left untouched.
- `git diff --check`: passed.
- Guardian feature/auth/onboarding files, shared Firebase configuration and existing Guardian backend service/case modules: no diff.
