# Application input audit and validation coverage

Audit completed before implementation on 2026-11-08, starting from
`origin/main` at `e10d1877bced730bc99e956b0e4ee21b76856c5a`, on
`feature/app-wide-input-validation-20261108`.

## Scope and evidence

Inspected the source inventory, router, all presentation files in `lib/features`,
shared widgets, controllers, validators, formatters, submission handlers,
`showDialog` and `showModalBottomSheet` builders. Searched for `TextField`,
`TextFormField`, `AppTextInput`, `PasswordInput`, `Form`, `FormField`, dropdowns,
checkboxes, chips, custom selections, and age references. Also inspected the web
entry point and backend administrative scripts. Reproduce the main inventory with:

```powershell
rg -n 'TextField|TextFormField|AppTextInput|PasswordInput|FormField|TextEditingController|validator:|inputFormatters:|showDialog|showModalBottomSheet' lib
rg -n 'onChanged:|onSelected:|Checkbox|Dropdown|ChoiceChip|OnboardingSelectionCard' lib
rg -n '\bage\b|enterAge' lib/features lib/shared
git ls-files '*.dart' '*.html' '*.js' '*.jsx' '*.ts' '*.tsx' '*.vue' '*.py'
```

The README describes an Admin Portal, but this checkout has no implemented Admin
UI or Admin route. `web/index.html` is the Flutter bootstrap, without HTML forms.
Administrative Python scripts use command-line arguments (and a password prompt
in `create_test_volunteer.py`), not application input widgets. Their existing
validation and backend business rules remain unchanged. AI assets are datasets,
embeddings, and experiment outputs, not application forms.

Only `IndividualFormScreen` accepts editable age, shared by Add and Edit. Other
age references are models, serialization, or read-only profile/card/QR displays.

Final scope correction: the user explicitly requested that the Guided Assistant
remain completely unchanged. Its source and dedicated test file are restored to
`origin/main`; the two newly added real-time Guided Assistant validation tests
and the temporary review probes were removed. The audit still lists its inputs,
but no new real-time validation is applied to them.

Source locations: [shared text input](../lib/shared/widgets/app_text_input.dart),
[password wrapper](../lib/shared/widgets/password_input.dart),
[required checkbox](../lib/shared/widgets/required_checkbox.dart),
[auth modes](../lib/features/auth/presentation/auth_screen.dart),
[existing validators](../lib/features/auth/presentation/form_validation.dart),
[Guardian profile edit](../lib/features/guardian/presentation/edit_guardian_profile_screen.dart),
[Individual Add/Edit](../lib/features/guardian/presentation/individual_form_screen.dart),
[retention](../lib/features/guardian/presentation/retention_period_panel.dart),
[guided workflow](../lib/features/guardian/presentation/guided_report_screen.dart),
[Volunteer identification/manual search](../lib/features/volunteer/presentation/volunteer_identification_views.dart),
[Volunteer filters](../lib/features/volunteer/presentation/volunteer_case_views.dart),
[Volunteer account/language](../lib/features/volunteer/presentation/volunteer_account_views.dart),
and [route inventory](../lib/core/routing/app_router.dart).

## Coverage matrix

Each row identifies a distinct editable field or selection. Shared screens list
every applicable mode. The behavior column records the final implementation.
Test abbreviations link to executable evidence below the matrix. Unchanged
controls without direct automated interaction tests are identified explicitly.

| Screen | User Role | Input Field | Existing Validation | Updated Validation Behavior | Test Coverage |
| --- | --- | --- | --- | --- | --- |
| Login | Guardian / Volunteer | Email | Required, email format | Per-field feedback after editing; clears on correction; submit safeguard | A Login (both roles, en/ar); G submit |
| Login | Guardian / Volunteer | Password | Required only; credentials checked by Firebase | Live required check; no registration-strength policy on login | A Login (both roles, en/ar); G submit |
| Register | Guardian | Full name | Required, trimmed length <=120 | Live existing rules after editing | A Register (en/ar); F boundaries |
| Register | Guardian | Email | Required, email format; ownership/account uniqueness server-side | Live format only; server decision unchanged | A Register (en/ar); F boundaries |
| Register | Guardian | Phone | Required, Saudi phone normalization | Live existing rules, including Arabic digits | A Register (en/ar); F normalization |
| Register | Guardian | Password | Required, 8+ upper/lower/digit/symbol | Live existing policy | A Register (en/ar); F policy |
| Register | Guardian | Confirm password | Required, exact match | Live match; rechecks touched confirmation when password changes | A Register (en/ar), source-password changes; G submit |
| Register | Guardian | Adult declaration | Must be checked at submit | Local required feedback after toggle and at submit | A Register (en/ar), check/uncheck/correct; G submit |
| Register | Guardian | Privacy agreement | Must be checked at submit | Local required feedback after toggle and at submit | A Register (en/ar), check/uncheck/correct; G submit |
| Complete profile | Guardian | Full name | Required, <=120 | Live existing rules | A Complete profile (en/ar) |
| Complete profile | Guardian | Phone | Required, Saudi format | Live existing rules | A Complete profile (en/ar) |
| Complete profile | Guardian | Adult declaration | Required | Local required feedback | A Complete profile submit (en/ar); shared toggle behavior in A Register |
| Complete profile | Guardian | Privacy agreement | Required | Local required feedback | A Complete profile submit (en/ar); shared toggle behavior in A Register |
| Reset password | Guardian / Volunteer | Email | Required, email format; neutral server response | Live format only; neutral response unchanged | A Reset (en/ar); G reset submission; S shared Volunteer reset (en/ar) |
| Edit Guardian profile | Guardian | Full name | Required, <=120 | Live rules, initially quiet even with existing value | A Edit Guardian profile (en/ar) |
| Edit Guardian profile | Guardian | Phone | Required, Saudi format | Live rules, including clearing existing value | A Edit Guardian profile (en/ar) |
| Add / Edit Individual | Guardian | Full name | Required, <=120 | Live existing rules | A Individual empty/correction (en/ar); shared name lifecycle in A Register; F boundaries; G Edit persistence |
| Add / Edit Individual | Guardian | Age | Integer 0–130 inclusive, required | Integer dropdown, 131 choices; new value null; edit value preserved; submit validation; localized Select age / اختر العمر placeholder | A Individual (en/ar): placeholder, empty/new/0, exact option range; A Edit ages 0/7/130 and changed integer payload; F invalid boundaries; G unchanged-age edit |
| Add / Edit Individual | Guardian | Gender buttons | Required FormField | Per-field autovalidation; submit error clears on selection | A Individual (en/ar), empty then valid, final form valid |
| Add / Edit Individual | Guardian | Relationship | Required dropdown | Per-field autovalidation; submit error clears on selection | A Individual (en/ar), empty/Other/Child, final form valid |
| Add / Edit Individual | Guardian | Other relationship description | Required only for Other | Live required check while visible; removed when condition ends | A Individual (en/ar), whitespace/valid/cleared/hidden; G Other |
| Add / Edit Individual | Guardian | Camera photo | Required for Add; replacement optional for Edit | Intentionally unchanged: cancelling the camera leaves photo and error state untouched; missing photo is checked on submit; successful capture clears the photo error | A original cancellation behavior, submission-time error and successful-capture recovery; G missing photo and edit without replacement; real device untested |
| Add / Edit Individual | Guardian | Retention period | Null means backend default on Add / unchanged on Edit; unavailable options disabled | Unchanged: null is valid; preserve backend availability and deadline rules | R default/current/changed/disabled/conditional/rejected/retry; G registration default |
| Guided report | Guardian | Same last-seen location Yes/No | Explicit answer advances step; GPS optional on Yes | Intentionally unchanged per user request; original UI, navigation and submission retained | Q existing No/progression; GPS Yes with real permission untested; source matches origin/main |
| Guided report | Guardian | Clothing description | Trimmed nonempty at submission, 1000-character formatter | Intentionally unchanged per user request; original TextField and submission-time error handling retained | Q existing populated answer/progression; no new real-time validation tests |
| Guided report | Guardian | Distinctive item Yes/No | Explicit answer controls next step | Intentionally unchanged per user request; original branching retained | Q existing Yes and No branches |
| Guided report | Guardian | Distinctive description | Nonempty only after Yes at submission, 1000-character formatter | Intentionally unchanged per user request; original conditional submission-time error handling retained | Q existing empty submission and valid description; no new real-time validation tests |
| Guided report | Guardian | Additional information | Optional, 2000-character formatter | Intentionally unchanged per user request; original text input and submission behavior retained | Q existing populated completion; no new real-time validation tests |
| Manual Review | Volunteer | Name search | Optional unrestricted search | Unchanged: empty and arbitrary queries valid | M no-result query, clear, matching query (en/ar) |
| Manual Review | Volunteer | Gender filter chips | Optional, All / male / female | Unchanged: no required selection | M Female and clear to All (en/ar); male click not directly tested |
| Identifier verification | Volunteer | Guardian verification code | Required; normalized six digits; actual match server-side | Live required/format feedback; valid format still requires server verification | V (en/ar): pristine/invalid/Arabic digits/empty/corrected; valid format with wrong code rejected, correct code accepted |
| Identifier verification | Volunteer | Authenticated account shown checkbox | Required; Verify disabled while unchecked; repository safeguard | Local feedback after unchecking; existing button/repository safeguards retained | V (en/ar): check/uncheck/error/disabled/recheck; repository gate in volunteer_merge_verification_test.dart |
| Notifications | Volunteer | All / priority filter | Boolean filtering only | Unchanged: no invalid state | Existing notification screen tests; filter clicks not directly automated |
| Cases | Volunteer | Available / My Cases categories | Boolean filtering only | Unchanged: no invalid state | volunteer_search_join_test.dart (en/ar) |
| QR case picker bottom sheet | Guardian | Active case selection | Only eligible cases listed; existing selection preserved on cancel | Unchanged: navigation choice, no editable/required text | G selected case context; guardian_status_refresh_test.dart; cancel not directly tested |
| Profile language bottom sheet | Guardian | Language | English / Arabic, current locale selected | Unchanged: selection applies immediately | G authenticated profile language switch |
| Profile language bottom sheet | Volunteer | Language | English / Arabic, current locale selected | Unchanged: selection applies immediately | Source review; sheet selection not directly automated |
| Language selection | All | Language cards | Supported locale already selected | Unchanged: no invalid state | L selected state/direction/font/large text |
| Role selection | Signed out | Guardian / Volunteer cards | Immediately route; actual role resolved by backend | Unchanged: navigation, no client role authorization | L both cards (en/ar); S backend role wins |
| Camera / QR capture | Guardian / Volunteer | Capture / accept / retake / scanner | Camera permission, initialization, size and scan checks | Unchanged: device errors already local; no manual age/text entry | volunteer_camera_lifecycle_test.dart, volunteer_capture_manual_review_test.dart with fakes; actual hardware untested |
| Confirmation dialogs / preview sheets | Guardian / Volunteer | Confirm / cancel, preview valid/invalid, preview capture | Explicit action only | Unchanged: no editable fields or missing-value state | G delete confirmation; V confirm/cancel/capture; volunteer_design_test.dart logout cancel; not every preview branch is directly automated |

Test references:

- **A**: [app_input_validation_test.dart](../test/app_input_validation_test.dart), 18 tests. Register, Login, Reset, Complete profile, Edit Guardian profile, Individual selections and relationship run in both locales. Age edit boundary/payload and photo recovery tests run in English.
- **F**: [form_validation_test.dart](../test/form_validation_test.dart), including localized boundary checks and Saudi phone/password policies.
- **G**: [guardian_flow_test.dart](../test/guardian_flow_test.dart), existing submission/persistence/navigation safeguards, updated age interaction and field-local declaration expectations.
- **Q**: [guided_report_questions_test.dart](../test/guided_report_questions_test.dart), the four original tests restored exactly from `origin/main`. No new Guided Assistant real-time validation tests remain.
- **V**: [volunteer_navigation_test.dart](../test/volunteer_navigation_test.dart), extended live code and declaration checks in both locales.
- **R**: [guardian_retention_event_test.dart](../test/guardian_retention_event_test.dart).
- **M**: [volunteer_manual_review_test.dart](../test/volunteer_manual_review_test.dart).
- **S**: [volunteer_shared_auth_test.dart](../test/volunteer_shared_auth_test.dart).
- **L**: [language_selection_screen_test.dart](../test/language_selection_screen_test.dart).

The Guardian notifications, case list/status, individual profile, home and QR
display; Volunteer account/badge, case details, matches, contact, result and
handover views; splash, privacy, session and gate screens contain no additional
editable data fields. Navigation, telephone actions, retry, and confirmation
buttons were reviewed; they are not text/selection validation forms. Read-only
email, account data and ages remain read-only.

## Boundaries

No API, Firebase rules, authentication policy, backend validation, retention,
role authorization, or business rule changes are authorized here. Email ownership
verification remains investigation only: registration currently creates the
Firebase account and Guardian profile; no ownership-verification flow was added.
The Guided Assistant is explicitly excluded from the real-time validation
changes at the user's request. Its UI, input, errors, questions, navigation and
submission remain identical to `origin/main`.
The camera `_capture()` method also matches `origin/main` exactly: cancellation
does not change either the photo or its validation error. Volunteer identifier
and account-confirmation controls retain their original enabled behavior during
requests; only their requested local validation was added. The existing busy-state
guard on the Verify action remains unchanged.

## Verification results

Executed on 2026-11-09 after the final scope corrections:

| Command | Actual result |
| --- | --- |
| `flutter analyze` | Exit 0; `No issues found! (ran in 8.7s)` |
| `flutter test --machine` (complete suite) | Exit 0; 294 passed, 0 failed, 0 skipped; final machine event `success: true` |
| `git diff --check` and `git diff --check origin/main` | Both exit 0; no whitespace errors |
| Guided Assistant source and dedicated test comparison | Both files match the exact origin/main bytes; Git diff is empty; new guided-validation tests and review probes removed |

Final output is retained locally in
[`build/final-scope-flutter-test.jsonl`](../build/final-scope-flutter-test.jsonl) and
[`build/final-scope-flutter-analyze.log`](../build/final-scope-flutter-analyze.log)
(ignored build artifacts). The current total is two lower than the initial 296-test
run because the newly introduced `Guided answers validate live and reset between
conditional steps` tests were removed, one for English and one for Arabic, when
the user requested the complete Guided Assistant revert. The four original
Guided Assistant tests remain unchanged from `origin/main`. This is an actual
removal of two feature-specific tests, not a different counting convention. The
18 tests in A remain present; the photo test was renamed and corrected to assert
the original camera behavior rather than removed. No further tests were removed
by the busy-state or formatting corrections. Initial
runs exposed test-code issues in dropdown property lookups and scrolling; the
localized placeholder assertion now checks rendered text. These issues were
corrected before the successful final full run. No dependency versions were
changed. Flutter commands needed access outside the workspace to acquire the
installed SDK cache lock.

Machine-event results are summarized in
[`build/final-scope-test-summary.json`](../build/final-scope-test-summary.json).
They confirm that all four original Guided Assistant tests and all 18 tests in A
executed, neither removed Guided Assistant validation case was discovered, and
no tests were skipped. Earlier temporary review probes were separate runs from
the ignored build directory and were never part of either full-suite total.

Final audit against `origin/main` at
`e10d1877bced730bc99e956b0e4ee21b76856c5a`: no additional unrelated behavioral
changes were found after the camera and Volunteer busy-state restores. Remaining
code changes implement client validation and the age dropdown/localized prompt;
remaining test and documentation changes support those features and preservation
of original behavior. Guided Assistant source/tests and the camera method are
unchanged. Backend code, APIs, authentication policies and dependency versions
have no changes. The regenerated review patch includes the three new UX files
and excludes pre-existing patch files, build artifacts and unrelated files.

All implemented editable data inputs with existing client requirements are
accounted for above, including the Guided Assistant intentionally left unchanged
per the final scope correction. Automated checks for the updated forms exercise
pristine, invalid, empty, corrected and conditional inputs, with client validation
kept separate from server decisions. The matrix also records unchanged selections
and specific interaction gaps; it does not claim every possible branch was
executed.

Widget tests use fake repositories, authentication, and platform services.
Expected Firebase/FCM initialization diagnostics occur in this environment;
passing tests do not establish live Firebase authentication, delivery, or backend
business-rule behavior. Actual camera/scanner, Android permissions, GPS Yes-path,
and end-to-end integer serialization against a live backend were not exercised.
Age persistence is tested through the existing integer `IndividualInput` and fake
repository; existing API tests also run in the full suite. Admin UI testing is
inaccessible because no Admin Portal source is implemented in this checkout.
The unchanged Volunteer language sheet and priority-filter clicks, male-filter
click, QR-picker cancellation, and some preview actions have no direct automated
interaction assertions, as marked in the matrix.
