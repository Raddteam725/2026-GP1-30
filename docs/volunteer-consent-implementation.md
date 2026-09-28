# Volunteer development consent implementation

## 1. Model and required versions

The authenticated `users/{uid}` record stores `terms_version`, `privacy_version`
(strings) and `terms_accepted_at`, `privacy_accepted_at` (Firestore timestamps).
Both required versions are **`draft-2026-09`**. These identify the approved
**development/academic documents**, not legally reviewed production policies.
No existing user record was backfilled or manually modified.

`backend/app/volunteer_consent.py` owns the required versions. Current consent
requires both matching versions and recorded timestamps. `consent_current` in an
API response is derived from those fields, not a permanent stored boolean.

## 2. Backend enforcement and acceptance

`GET /v1/volunteer` permits the existing authenticated, enabled Volunteer to
restore their own account and retrieve consent requirements. Before consent it
returns no event access (`event_id: null`, `assigned: false`); this does not remove
or alter the actual assignment document.

Authenticated `POST /v1/volunteer/consent` accepts only:

```json
{
  "accepted": true,
  "terms_version": "draft-2026-09",
  "privacy_version": "draft-2026-09"
}
```

A transaction rechecks the Volunteer role/account, validates the required versions,
and writes both versions and server timestamps. False/non-boolean acceptance,
stale versions and client-supplied timestamps are rejected. An identical retry
preserves the original timestamps. An unavailable event or missing assignment does
not prevent accepting the documents; it still prevents event participation.

Protected service operations require current consent by default, including cases,
Start/Join Search, photos, Manual Review, Found Reports, Guardian contact,
verification, handover, notification history/read state and FCM/location registration.
Authentication/session recovery and owned-device unregistration/logout remain
available. Guardian consent and APIs were not changed.

Notification dispatch and queued-send execution both check current consent. An
old FCM registration cannot continue receiving new case pushes after required
consent becomes outdated. A push already accepted by FCM cannot be recalled.

## 3. First login, return and future versions

The canonical `VolunteerEntry` loads the authoritative profile, then uses
`VolunteerConsentGate`. The protected workspace, its FCM service and location
service are not created before current consent. The checkbox starts unchecked;
Accept & Continue is disabled until checked. Not Now uses the existing logout
callback without deactivating the account or changing assignment.

After a successful acceptance, the app reloads the profile before proceeding.
A returning user skips consent only when the server reports both current versions.
Account enablement, assignment and actual location checks remain in force.

Changing a required backend version invalidates previous acceptance. Existing
profile refresh and protected-request failures return the app to consent, clear
protected client data and stop participation location. The new document content
and its version must also be shipped in Flutter: an older build refuses to accept
a version whose document it does not contain and shows an update message. No
automatic acceptance or Firebase migration occurs.

## 4. Documents and location

Terms and Privacy open separate scrollable pages with ordinary back navigation,
in the current application language and direction. Their full content is copied
from `docs/volunteer-terms-privacy-drafts.md` into the existing ARB localization
system, without substantive rewrites. Both pages display the development notice
and document version. The same links are available later in Volunteer Profile;
viewing them never writes acceptance.

Acceptance does not grant Android permission or mark it granted. The existing
Location Required explanation precedes the actual OS permission request. Denied
or revoked permission and disabled Location Services still block event functions.
A temporarily unavailable GPS estimate does not block participation when permission
and services remain valid. Consent loss during participation stops location access.

## 5. Exact first-login screen text

### English

Welcome to Radd

Before using Radd as a Volunteer, please review the following conditions and Radd’s Terms of Use and Privacy Policy.

Development / academic project documents — not legally reviewed production policies.

By participating as a Volunteer, you acknowledge that:

• Location access is required during active event participation.

• Radd may update your location while you are actively participating, including while the app is running in the background, to support event coordination and proximity-based Volunteer prioritization.

• If location permission is denied or revoked, or Location Services are disabled, you cannot access the event workflow until location access is restored.

• You may access personal and Guardian information only when authorized and only for identification and reunification purposes.

• Potential AI or Manual Review matches do not confirm identity automatically. Identity must be explicitly confirmed, and Guardian verification is required before handover.

• You must use only your authorized Volunteer account and must not share protected information outside the approved Radd workflow.

Terms of Use

Privacy Policy

I have read and agree to Radd’s Terms of Use and Privacy Policy.

Accept & Continue

Not Now

`draft-2026-09` appears below each document link.

### العربية

مرحبًا بك في Radd

قبل استخدام Radd كمتطوع، يرجى مراجعة الشروط التالية وشروط استخدام Radd وسياسة الخصوصية.

وثائق مشروع تطويري / أكاديمي — ليست سياسات إنتاجية خضعت لمراجعة قانونية.

بمشاركتك كمتطوع، فإنك تقر بما يلي:

• الوصول إلى الموقع مطلوب أثناء المشاركة في الفعالية النشطة.

• قد يقوم Radd بتحديث موقعك أثناء مشاركتك الفعلية، بما في ذلك أثناء عمل التطبيق في الخلفية، لدعم تنسيق العمل وإعطاء الأولوية للمتطوعين القريبين.

• إذا تم رفض إذن الموقع أو سحبه، أو تم تعطيل خدمات الموقع، فلن تتمكن من استخدام وظائف الفعالية حتى يتم استعادة الوصول إلى الموقع.

• لا يجوز لك الاطلاع على البيانات الشخصية أو بيانات تواصل ولي الأمر إلا عندما تكون مخولًا بذلك ولأغراض التعرف وإعادة الجمع فقط.

• نتائج الذكاء الاصطناعي أو المراجعة اليدوية لا تؤكد الهوية تلقائيًا؛ يجب تأكيد الهوية صراحةً والتحقق من ولي الأمر قبل التسليم.

• يجب استخدام حساب المتطوع المصرح لك به فقط، وعدم مشاركة المعلومات المحمية خارج مسار العمل المعتمد في Radd.

شروط الاستخدام

سياسة الخصوصية

قرأت شروط استخدام Radd وسياسة الخصوصية وأوافق عليهما.

موافق ومتابعة

ليس الآن

تظهر النسخة `draft-2026-09` أسفل رابط كل وثيقة.

## 6. Files changed in this consent pass

Earlier uncommitted work was preserved. This pass touched:

- Backend: `backend/app/volunteer_consent.py` (new), `backend/app/volunteer.py`,
  `backend/app/volunteer_alerts.py`.
- Flutter: `lib/features/volunteer/presentation/volunteer_consent_screen.dart`
  (new), `volunteer_entry.dart`, `volunteer_workspace.dart`,
  `volunteer_account_views.dart`, and
  `lib/features/volunteer/data/api_volunteer_repository.dart`.
- Localization: `lib/core/localization/arb/app_en.arb`, `app_ar.arb`, and generated
  `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ar.dart`.
- Backend tests: `backend/tests/test_volunteer_consent.py` (new),
  `test_volunteer.py` (existing accepted-user fixture), `test_volunteer_alert_delivery.py`.
- Flutter tests: `test/volunteer_consent_test.dart` (new),
  `volunteer_location_gate_test.dart`, `volunteer_design_test.dart`.
- Existing API test fixtures explicitly declare current consent:
  `test/api_volunteer_repository_test.dart`, `api_volunteer_workflow_test.dart`,
  `standalone_found_report_api_test.dart`, `volunteer_assignment_test.dart`,
  `volunteer_capture_manual_review_test.dart`, `volunteer_identification_contract_test.dart`,
  `volunteer_manual_only_test.dart`, `volunteer_merge_verification_test.dart`,
  `volunteer_retention_api_test.dart`.
- Documentation: this report.

## 7. Validation

- Full backend suite: **233 passed**, 56 existing SDK/deprecation warnings.
- Full Flutter suite: **214 passed**, including Guardian regressions.
- `flutter analyze`: **no issues**.
- Changed Dart files formatted; `git diff --check`: **passed**.
- Android debug APK: **built successfully**, with the existing Kotlin migration advisory.
  File: `build/app/outputs/flutter-apk/app-debug.apk`.
  Existing development URL: `http://127.0.0.1:8000` (requires adb reverse).

Tests cover strict explicit acceptance, server timestamps, identical retries,
wrong/stale versions, every protected Volunteer route, queued notification blocking,
bilingual unchecked/disabled controls, document/back navigation, Not Now,
session restoration, future-version mismatch, Profile document access and
consent-to-location separation. The location integration tests exercise denied
permission before the OS request, enabled services without a GPS fix, disabled
services, recovery and stopping location when consent becomes outdated.

## 8. Controlled live verification still required

No Firebase records were manually changed, no consent was submitted live, and
no APK was installed or mutating emulator action performed in this pass. No commit
or push was made. Existing Found Reports, assignments and registrations were not
changed.

Restart the local backend with the current code before installing/testing the
new APK. The build does not update a running backend process. Keep the existing
ADC, API URL and adb reverse setup; do not add consent fields manually.

With an existing test Volunteer, verify the consent screen appears; open both
localized documents; confirm unchecked/disabled behavior; choose explicit acceptance
once; then separately grant Android location permission. Verify returning login
skips consent, Profile links work, and denied permission/disabled services still
block participation. This is the user's controlled live test, not a claim of live
Firebase/device verification from automated tests.
