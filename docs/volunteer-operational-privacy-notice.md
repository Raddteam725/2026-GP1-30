# Volunteer operational onboarding / privacy correction

## Verified starting point

Before any edit, the branch was `volunteer-privacy-fix`, the working tree was clean,
and HEAD, local main and origin/main all resolved to
`c9344f7ddc2d0fe240af5431354340104115cd25`. The current independent Manual Review,
standalone Found Report continuation by authoritative status, refresh race guard,
and regression tests were present. No branch switch or history operation occurred.

## Current model (supersedes the mandatory consent implementation)

Outside Radd: organization selects the Volunteer, trains/informs them about the
workflow and operational requirements, handles organizational agreements externally,
then authorized administration provisions the account and assigns an event.

Inside Radd: login → authenticated role/account/event checks → mandatory location
onboarding when location requirements are not satisfied → Location & Privacy Notice
→ Continue → actual Android permission → Location Services/current eligibility checks
→ event workflow. A returning Volunteer with valid permissions/services proceeds
without another notice interruption. Continue is not legal consent and records no
acceptance. There is no notice-seen flag that can override device checks.

Removed: the consent gate, checkbox, Accept & Continue / Not Now consent decision,
client consent state/requests, server consent-version prerequisites, consent endpoint
and model, and consent-based notification eligibility checks. Existing legacy
`terms_version`, `privacy_version`, `terms_accepted_at`, `privacy_accepted_at` fields
are ignored. No Firebase data was read, migrated, deleted or modified in this task.
Historical documentation is retained for reference.

## Exact notice

### English — Location & Privacy Notice

Location access is required while participating in the active event. Radd uses your location to support event coordination and proximity-based Volunteer prioritization. Location may continue updating in the background during active event participation.

Actions: **View Privacy Policy**; **Continue**.

### العربية — إشعار الموقع والخصوصية

الوصول إلى الموقع مطلوب أثناء المشاركة في الفعالية النشطة. يستخدم Radd موقعك لدعم تنسيق العمل وإعطاء الأولوية للمتطوعين القريبين، وقد يستمر تحديث الموقع في الخلفية أثناء المشاركة الفعلية.

الإجراءات: **عرض سياسة الخصوصية**؛ **متابعة**.

The existing Open Settings recovery replaces the permission-request action when
permission is permanently denied or device Location Services are disabled.

## Documents and preserved boundaries

The notice opens the complete Volunteer Privacy Policy in the current language,
with normal back navigation and the development/non-legally-reviewed disclaimer.
The outdated description of future in-app consent records in that policy was
replaced with the external organizational-onboarding/informational-notice model.
No operational AI matching is claimed. Terms are not part of mandatory onboarding.
The existing optional Profile document links were preserved, not newly added or
expanded; their display versions are document labels, never authorization conditions.
The document renderer was extracted from the removed consent screen into
`volunteer_policy_screen.dart`.

Authentication, enabled account and current Active Event assignment remain enforced
by backend authorization. Actual Android permission/services gating remains in the
existing app location service; removal of consent adds no bypass. Permission denial,
revocation or disabled services blocks participation. A missing GPS estimate alone
does not block participation/standard alerts; proximity prioritization still requires
a suitable estimate. Existing authorized background foreground-service location and
stopping on logout/deactivation/unassignment/event loss/device-access loss remain.

No Guardian implementation or privacy flow was changed. The current Manual Review,
identity confirmation, contact privacy, standalone status resume, QR/identifier,
handover, Reunited and retention implementation files were not replaced or reverted.
Workspace edits are limited to removing consent dependencies and rendering the
location notice. Existing full regression suites cover the preserved functionality.

## Validation

- Full Flutter: **249 passed**.
- Full backend: **245 passed**, 57 existing SDK/deprecation warnings.
- `flutter analyze`: no issues.
- Changed Dart files formatted; `git diff --check`: passed.
- Android debug APK: built successfully, with existing Kotlin migration advisory.
  The existing development URL remains `http://127.0.0.1:8000` (adb reverse required).
- No APK installation, emulator interaction, Firebase operation, commit or push.

Obsolete consent tests were removed/replaced, so test counts are not comparable
one-for-one with the previous baseline. New tests cover missing/outdated ignored
consent fields, unchanged account/assignment guards and untouched legacy data;
FCM delivery no longer depends on consent; bilingual notice/privacy navigation;
no checkbox or required Terms; denied permission after Continue; permission recovery,
revocation, disabled services, no GPS estimate and returning-user navigation.

## Short controlled live test

1. Restart the backend with this branch's code and install the new debug build;
   keep the existing ADC/API URL/adb reverse setup. Do not modify Firebase fields.
2. Sign in with an existing enabled, assigned test Volunteer. With location access
   missing, expect the informational notice (no acceptance checkbox). Open Privacy
   Policy and return; check Arabic and English.
3. Tap Continue. Deny the real Android permission: event functions stay blocked.
   Retry/grant permission and enable services: event functions become available.
4. Navigate Home/Cases/Report and reopen the app with valid permission/services:
   no recurring notice. Disable services or revoke permission: participation blocks
   again; restore them to recover. A temporary missing estimate alone must not block.
5. Resume the existing standalone Found Report to its stored verification stage.
   Do not reset/create another report merely to test onboarding.

These steps are pending user-controlled live testing; automated tests are not
claims of live device/Firebase verification.

## Exact task file manifest

Branch: `volunteer-privacy-fix`; 15 modified, 4 deleted obsolete files, 3 new files. Nothing staged.

```text
 M backend/app/volunteer.py
 M backend/app/volunteer_alerts.py
 D backend/app/volunteer_consent.py
 M backend/tests/test_volunteer.py
 M backend/tests/test_volunteer_alert_delivery.py
 D backend/tests/test_volunteer_consent.py
 M lib/core/localization/arb/app_ar.arb
 M lib/core/localization/arb/app_en.arb
 M lib/core/localization/generated/app_localizations.dart
 M lib/core/localization/generated/app_localizations_ar.dart
 M lib/core/localization/generated/app_localizations_en.dart
 M lib/features/volunteer/data/api_volunteer_repository.dart
 D lib/features/volunteer/presentation/volunteer_consent_screen.dart
 M lib/features/volunteer/presentation/volunteer_entry.dart
 M lib/features/volunteer/presentation/volunteer_workspace.dart
 M test/api_volunteer_repository_test.dart
 D test/volunteer_consent_test.dart
 M test/volunteer_design_test.dart
 M test/volunteer_location_gate_test.dart
?? backend/tests/test_volunteer_operational_access.py
?? docs/volunteer-operational-privacy-notice.md
?? lib/features/volunteer/presentation/volunteer_policy_screen.dart
```
