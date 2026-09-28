# Standalone Found Individual Reports

Implemented on the existing working tree. No missing-person case is synthesized,
no Admin UI or AI engine was added, and no live Firebase records were created or
migrated during implementation. Earlier working-tree changes are preserved.

## Domain and authorization

`found_reports/{FR-id}` remains separate from `cases/{RD-id}`. FR IDs retain the
existing deterministic request-id scheme (idempotent submission). New reports have
`origin: volunteer_found`, `event_id`, `volunteer_uid`, `created_at`, `updated_at`,
`ai_status: unavailable`, and the temporary `photo_path` while identifying.

Central lifecycle constants live in `backend/app/found_reports.py`; Flutter uses
`FoundStatus`:

| Internal value | Display |
| --- | --- |
| `identification_in_progress` | Identification in Progress |
| `identity_confirmed` | Identity Confirmed |
| `awaiting_guardian_verification` | Awaiting Guardian Verification |
| `reunited` | Reunited |

The existing explicit End Identification action remains represented by `ended`
and `ended_at`; ended attempts are excluded from active lists. It does not close
any Missing Case. No additional successful terminal status was invented.

Reads/actions preserve the existing reporter-owned authorization model: the
reporting Volunteer must remain authenticated, enabled, assigned to the current
Active Event, and authorized to participate under existing location gating.
Other Volunteers cannot take over this report merely by guessing its ID. Active
reports are resumable from Report only; Cases contains Guardian Missing Cases.
They never receive Start Search / Join Search controls. No new navigation tab.

Identity confirmation records `matched_profile_id`, `guardian_id`, `individual_id`,
`individual_path`, `confirmed_by`, and sets the registration's
`active_found_report_id` transactionally. Selecting a profile alone does not confirm
identity or expose Guardian contact through the Found Report context. After explicit
confirmation, the report's authorized details resolve contact from the real Guardian
account. Duplicate identification of the same registration by competing Found
Reports is rejected transactionally. Registration edits/deletion are blocked while
its active reunification reference exists.

## Shared verification, linking and handover

`reunification_context()` resolves either the real linked Missing Case or the
standalone Found Report. Both use the same verification/handover implementation.
The existing Guardian-account QR remains short-lived and single-use; verification
checks Guardian, event, expiry, consumption and confirming Volunteer. Failed QR or
identifier verification clears proof and prevents handover.

Receipts include `context_type` (`found_report` / `missing_case`), `context_id`,
Guardian/Volunteer references and verification time. Existing Missing Case receipts
and their `case_id` remain compatible. Standalone fallback records
`method: found_identifier`; linked Missing Cases retain `case_identifier`; QR is
`qr`. The identifier input accepts `identifier` and the legacy `case_id` alias.

Guardian QR now lists identifiers returned by authenticated
`GET /v1/guardian/found-reports`, scoped to that Guardian and current event. The
Volunteer compares the full FR identifier displayed in the authenticated Guardian
app; the existing requirement to see that authenticated account remains. No fake
Missing Case identifier is used.

If a Missing Case exists first, confirmation links the FR to that case and continues
its Match Confirmed → verification → Reunited path. If an identified FR exists first,
a later genuine Guardian report creates the genuine RD origin and links it to the
same workflow, starting at Match Confirmed or Awaiting Guardian Verification. It
creates no search alert. Any existing verification proof is transferred to the
linked context atomically, so verification is not repeated unnecessarily. All later
operations resolve through that one authoritative context. Guardian cancellation/
resolution closes the linked operational attempt using the existing ended flag.

No standalone FR contributes to Missing Case counts. Only actual Guardian-created
RD documents contribute. `found_reports.monitoring(db, event_id, active_only=True)`
is a trusted internal future-Admin query contract: IDs, status, event, reporting
Volunteer, creation/update, identified profile link and completion metadata. A future
Admin API must authorize callers before invoking it. No public Admin endpoint or
new dashboard metric was introduced.

## Retention

The captured Found photo is deleted immediately after explicit identity confirmation,
or when an identification attempt ends; the existing durable deletion retry queue
remains. Handover does not depend on that deleted image. Registered photographs
remain independent.

The registration's original expiry is never changed. Cleanup now recognizes an
identified active FR as a **deletion hold only**. An expired registration is not
returned to general Manual Review or allowed to create new missing reports because
of that hold. The authorized, already-confirmed report can still resolve the
registration/contact and its context-specific registered-photo endpoint. Existing
Missing Case deferrals remain unchanged.

On standalone Reunited, the same transaction clears the registration's active FR
reference and replaces the FR with the centralized `minimal_completed` allowlist:
`origin`, `event_id`, final `status`, `created_at`, `updated_at`, `handed_over_at`,
`handed_over_by`, `verification_method` (document ID remains). No Guardian/person
reference, contact, name, snapshot, photo path or QR secret remains. Completed
reports cannot be reidentified/reverified or restarted as new attempts.

A still-valid registration remains intact. An expired registration is deleted by
the existing cleanup mechanism once no other approved hold remains. Account records
are not deleted. There is no invented terminal-FR duration or automatic application
of the Missing Case 24-hour rule. Linked RD workflow retention remains governed by
its existing case rules; the case scrubber preserves a minimal completed FR outcome
rather than losing that report origin.

## Manual Review bug

The production `_submitCapture()` saved the report and then immediately selected
`IdentificationState.processing`, navigated to `VolunteerView.finding`, and invoked
`_loadCandidates()`. It skipped the ready identification screen with its two action
buttons; the processing screen's Manual Review control was lower down below the
large progress content.

The corrected production transition is `ready` → `matches`, without any automatic
AI request. Find Match with AI is the first primary button; Manual Review is the
second secondary button at the same stage. Its availability does not depend on AI
execution/failure or a Missing Case. No Home/bottom-navigation shortcut was added.

The bilingual regression drives the actual VolunteerCapture route, Capture, preview
and Use Photo with an isolated camera platform and API fixture. It asserts the real
photo submission, a standalone report, both action styles, and zero AI requests before
or after opening Manual Review. Fixtures exist only in tests; production retains the
real camera and backend.

## Live verification boundary and manual test

The connected emulator was inspected read-only and was signed in as the existing
Saud test Volunteer. The user chose to perform Use Photo personally. Consequently
this implementation does **not** claim that a newly saved live report has been tested
on the emulator. No new report was created and no registration/event/legacy retention data was
changed; no destructive cleanup worker was enabled. See the unintended search-join
incident below before treating the emulator inspection as read-only.

After the updated backend and APK are running:

1. Report → Open Camera → Capture → Preview → Use Photo.
2. Confirm both Find Match with AI and Manual Review are visible immediately.
3. Open Manual Review without invoking AI. Choose a new, valid registration for the
   configured Active Event (the 17 legacy registrations remain excluded).
4. Confirm Identity, then Guardian Contact → Proceed to Verification.
5. Guardian opens QR in their authenticated account. Scan that real QR, or compare
   the full Found Report identifier shown there using the fallback option.
6. Invalid verification must prevent handover. Valid verification alone must not
   mark Reunited; explicitly confirm handover afterward.
7. The standalone report becomes Reunited and disappears from active FR lists;
   no RD document is created. Its identifiable FR fields are minimized. A valid
   registration remains; an expired registration awaits the existing due cleanup.

AI remains intentionally unavailable. No new Found Report push category was invented;
existing Missing Case events/FCM remain in place, and FR visibility uses normal
list loading/resume recovery. Guardian opens its QR view for standalone coordination.

## Validation and runtime preparation

- Full backend suite: **193 passed** (56 existing SDK deprecation warnings).
- Full Flutter suite: **205 passed**.
- `flutter analyze`: no issues; changed Dart files formatted.
- `git diff --check`: passed; no unresolved Git merge paths.
- Android debug build: succeeded (existing Kotlin migration advisory).
- Installed the debug APK on emulator-5554 with `adb install -r`; app data/session
  retained. Verified the real Saud session returns to Volunteer Home with real
  available/my cases. Opened Report only; no photograph was submitted.
- Restarted the verified local shared backend on 127.0.0.1:8000 with
  `RADD_LOCAL_JOBS=0`; adb reverse maps port 8000. No cleanup worker enabled.
- Actual live Use Photo → both buttons, real Guardian QR/fallback and handover
  remain for the user's controlled test; automated tests do not claim those live
  Firebase actions have been performed.

Files changed for this pass: `backend/app/found_reports.py` (new),
`volunteer_workflow.py`, `cases.py`, `cleanup.py`, `service.py`, `main.py`;
Volunteer identification/case views, API repository and models; Guardian QR view,
repository/API; both ARBs and generated localization files; backend workflow tests;
Flutter capture/manual-review and standalone API tests (new), Guardian flow/fakes
and existing verification fixture; this document and registration-retention notes.
No commit or push performed.

### Emulator inspection follow-up and unintended action

After the initial Report screen check, a coordinate-based tap encountered a
changed Cases screen instead of the previously inspected Report card. Android
logs show a successful `POST /cases/{id}/start-search` at device time
2026-09-28 21:42:41. No further mutating UI actions were attempted, and no automatic
rollback was made. A read-only audit found Saud now joined to
`RD-03823AFEEC94` (which appeared under Available Cases before inspection), as well
as the previously joined `RD-3B5E8DE1E338`. The former was already Search in Progress;
this is an additional Volunteer join, not creation/resolution of a case. The
request log redacts the case ID, so the affected ID is identified by before/after
list state and the read-only Firestore membership check. The initially suspected
visible `RD-4599FEE6F0AE` was checked and Saud is not joined to it.

The existing Found Report was subsequently loaded using GET requests only. After
the photo request settled, the emulator displayed Find Match with AI and Manual
Review together, followed by End Identification Attempt. AI was not invoked and
no new Found Report was created. Fresh Capture → Use Photo remains for the user,
who explicitly elected to perform that live action personally. The unintended
search join above needs user review; it must not be described as a wholly
read-only emulator session.

## Manual-only entry (subsequent approved UX change)

The initial Report screen now shows primary Open Camera followed immediately by
secondary Manual Review, in Arabic and English. Post-capture Manual Review remains
available; no Home or bottom-navigation entry was added. Browsing, search, gender
filters and profile selection do not create reports or expose Guardian contact.

Explicit Confirm Identity (including confirmation dialog) calls authenticated
`POST /v1/volunteer/found-reports/manual` with `request_id` and `profile_id`.
The existing shared confirmation transaction creates the report and links the
registration atomically. It rechecks account, event assignment, participation,
registration retention and competing workflow state. Invalid confirmation does
not leave a partially created report. Retried requests use a deterministic FR ID
with a manual-specific namespace; no Missing Case is manufactured.

The report has `origin: volunteer_found`, `identification_method: manual`,
`ai_status: not_requested`, the existing event/reporter/timestamps and confirmed
identity references. It has **no photo_path**, no uploaded image and no placeholder
image. Its first committed status is `identity_confirmed`; the response reports
`photo_available: false`. It then uses the existing Guardian contact, QR/identifier,
handover and centralized retention/minimization logic. A genuine existing Missing
Case may be linked using the unchanged confirmation rules.

The camera submission endpoint still requires a valid photograph. AI candidate
requests additionally reject an identifying report without a stored photograph.
No AI engine or artificial result was introduced.

Validation: 196 backend tests and 208 Flutter tests passed. Manual-only tests cover
both languages, private browsing, explicit confirmation, no photo submission,
no AI calls, standalone context, and both QR/identifier handover on the backend.
No live Firebase mutation or mutating emulator interaction was performed for this
change. Install the newly built APK and restart the backend before the user's
controlled live test; automated fixtures do not claim live verification.

The user approved retaining Saud's earlier join to RD-03823AFEEC94 for multi-
Volunteer testing. No rollback or further automatic mutating emulator actions
are authorized or were performed in this pass.

The subsequent Cases/notification/location correction is documented in
`volunteer-notification-location-corrections.md`; Found Reports are no longer listed
in Cases and remain accessible through Report.
