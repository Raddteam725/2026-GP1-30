# Manual confirmation live diagnosis

The emulator POST failed with HTTP 405 (latest attempts at device times
2026-09-28 22:45:54 and 22:47:14). The running backend PID 49577 exposed only
GET /v1/volunteer/found-reports/{report_id}; its OpenAPI did not contain the manual
POST endpoint. Consequently `manual` matched the dynamic GET-only path and the
request was rejected before the handler, photo validation or Firestore transaction.
The Flutter log redacted the static manual segment as {id}, obscuring diagnosis.

Restarted the verified local server from the same working tree, with
RADD_LOCAL_JOBS=0. OpenAPI now exposes POST /v1/volunteer/found-reports/manual.
No report submission, verification, cleanup, assignment or account mutation was
performed as part of diagnosis. Automatic client requests may continue normally.

Read-only Firebase audit: project radd-32eb6; current event C8fES02usly6UXgMh6sl;
Saud active and assigned. test123 has valid registration retention until
2026-10-01 17:51:35.314448 UTC, no active_case_id, but is already linked through
active_found_report_id to FR-2b6e7a21402fd4f5b06012df4afbfffb7b738545. That report
was created at 2026-09-28 19:20:44.745 UTC via the earlier photo path, not manual;
its status is awaiting_guardian_verification and the found photo is already absent.
Device logs independently show successful photo submission, confirm-match and
begin-verification around 22:20 device time. There is also the earlier unmatched
FR-6f22e7a5e95bb9a9e5b9cfc4cdc44e1b8e36bc79. No manual report was found for Saud.
The failed 405 requests did not execute a write handler. No partial-write cleanup
is proposed or required; the existing confirmed workflow must not be unlocked.

For test123, resume the existing report from Report and continue Guardian
verification. Do not start a second confirmation for the same individual. For a
separately approved, eligible and unlocked test registration the corrected server
supports one manual confirmation request; do not create extra records as a workaround.

Code changes: API route logging preserves the static manual path, and logs a
safe specific diagnostic for HTTP 405 in development. The user-facing message
remains nontechnical. Added an HTTP-level regression for no-photo manual submission,
identity linkage, absence of a Missing Case, response contract and idempotent retry.
Existing QR/handover and privacy tests remain.

Validation: backend 198 passed; Flutter 211 passed; analyzer no issues;
git diff --check passed; Android debug build succeeded (existing Kotlin advisory).
No commit/push, no APK installation or mutating emulator interaction.

## Consent dependency

Existing Guardian privacy model uses privacy_notice_version=sprint0-interim-1 and
server privacy_acknowledged_at. A complete Terms of Use document/version was not
found. The user was asked for approved bilingual Terms/Privacy texts/version IDs,
or authorization to prepare a draft for review. No legal content, acceptance or
consent flag has been fabricated. The new consent gate is pending that input.
The intended implementation will store separate accepted terms/privacy versions
and server timestamps under the authenticated user's document, enforce required
versions before Volunteer participation, and keep Android location permission as
an independent subsequent requirement. Guardian behavior must remain unchanged.
