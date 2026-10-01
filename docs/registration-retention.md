# Registration retention implementation

## Model and behavior

`events/{eventId}` keeps the existing `active` flag and adds:

| Field | Firestore type | Contract |
| --- | --- | --- |
| `starts_at` | Timestamp | Timezone-aware start; immutable once activated |
| `ends_at` | Timestamp | End; extend-only once activated |
| `registration_periods` | Array of maps | Each map has unique string `id` and positive integer `duration_hours` |
| `activated_at` | Timestamp | Management guard once the development configurator initializes an Active event |
| `updated_at`, `updated_by` | Timestamp, string | Configuration audit |

The Guardian does not select an event. The backend resolves the single Active
Event and returns only options with `server_now + duration <= ends_at`, while
`starts_at <= server_now < ends_at`. Missing configuration fails closed with a
localized unavailable message. The Admin Portal is not implemented.

`users/{guardianUid}/individuals/{individualId}` retains `event_id` and stores:

- `registration_started_at`: server UTC time established in the successful save transaction.
- `registration_expires_at`: that start plus the selected configured duration.
- `registration_period_id`: selected option ID.
- `registration_duration_hours`: duration snapshot.

If selection is omitted, the longest currently valid option applies. The server
revalidates on submission, so an option becoming invalid while a form is open is
rejected. Clients cannot supply authoritative timestamps. Photo replacement,
event extension and Admin edits of the option list do not change an established
expiry. The Guardian may change the chosen period from the individual's profile
(`registration_retention.reschedule`): the start is kept, the new deadline must
still be in the future and within the event, and the active-case edit lock applies.
Replacing a photo clears any old embedding; an eventual real embedding pipeline
must use the same stored expiry. No face-matching engine was added.

## Eligibility and deletion

The old `PHOTO_FRESHNESS` / capture-plus-24-hour check has been removed. The
compatibility response name `photo_expired` now describes unavailable registration
retention, not capture age. Capture timestamps remain metadata only.

Production consumers use the same retention helper:

- `service.py`: Guardian profile summary, registered photo serving and edits.
- `cases.py`: new missing report eligibility and Active Event match.
- `volunteer.py`: case reference photograph access.
- `volunteer_workflow.py`: Manual Review, registration photo access and confirmation.
- `cleanup.py`: full expired identifiable-registration deletion.

A known unexpired registration is eligible subject to existing ownership, event,
assignment, case-status and workflow checks. If expired, a linked nonterminal case
with matching event/Guardian can defer deletion and allow its context-specific
reference access only; it does not restore general registration eligibility. Manual Review still limits its
case-linked selection to open search stages; confirmed cases retain their existing
authorized handover flow. Unknown legacy expiry is never guessed valid.

The existing `expire_photos` job name now processes registration expiry. It reads
associated cases, defers for any nonterminal/unresolved case, validates ownership
and storage paths, and transactionally sets a deletion fence. It deletes photo and
embedding objects before deleting the registration (including any inline embedding).
Storage failure preserves references and the fence for retry. Associated terminal
case details are scrubbed to existing minimal statistics. Repeated runs are safe.
Guardian and Volunteer accounts are not deleted. Terminal outcomes are
`reunited`, `resolved`, `cancelled`, and the Admin closure `referred_to_authority`.

The existing opt-in local job invokes cleanup every 60 seconds. Deletion occurs
on the next successful check, not necessarily at the exact expiry instant. Access
checks enforce expiry independently of the scheduler. No production scheduler was
introduced. The separate 24-hour **terminal case** scrubber remains; this is not a
registered photograph lifetime.

Found Report photographs retain their separate lifecycle: delete when an attempt
ends or immediately on confirmed match, with retry for interrupted Storage deletion.
Standalone Found Reports still do not manufacture missing-person cases.

## Safe development configuration (not executed)

Run from the Radd project directory using the existing ADC. Choose actual test
event dates and durations yourself; the placeholders below are deliberately not
invented production values. Both timestamps require an explicit timezone. The
current event must fall between them and at least one duration must fit before its
end. Do not change an already-established Active event start or shorten its end.

```zsh
RADD_TEST_EVENT='C8fES02usly6UXgMh6sl'
RADD_EVENT_START='<approved ISO start with timezone>'
RADD_EVENT_END='<approved ISO end with timezone>'
RADD_SHORT_HOURS='<approved integer hours>'
RADD_LONG_HOURS='<approved integer hours>'
RADD_CONFIG_ACTOR='<your operator identifier>'
```

Preview first (no writes):

```zsh
backend/.venv/bin/python backend/scripts/configure_registration_periods.py \
  --project radd-32eb6 --event-id "$RADD_TEST_EVENT" \
  --starts-at "$RADD_EVENT_START" --ends-at "$RADD_EVENT_END" \
  --period "short:$RADD_SHORT_HOURS" --period "long:$RADD_LONG_HOURS" \
  --actor "$RADD_CONFIG_ACTOR"
```

Only after reviewing that preview and explicitly deciding to configure the event,
repeat the same command with `--apply`:

```zsh
backend/.venv/bin/python backend/scripts/configure_registration_periods.py \
  --project radd-32eb6 --event-id "$RADD_TEST_EVENT" \
  --starts-at "$RADD_EVENT_START" --ends-at "$RADD_EVENT_END" \
  --period "short:$RADD_SHORT_HOURS" --period "long:$RADD_LONG_HOURS" \
  --actor "$RADD_CONFIG_ACTOR" --apply
```

This changes event configuration only. It does not migrate existing registrations.
The script verifies project and single Active Event and revalidates transactionally.
Use the current backend code when testing (restart an older local backend process).
The local worker may be enabled for approved development cleanup using the existing
`RADD_LOCAL_JOBS=1` mechanism and one Uvicorn worker; it performs real due deletions,
so it was not enabled/run against Firebase during this verification.

## Read-only Firebase legacy audit — 2026-09-28

Project `radd-32eb6`; current Active Event `C8fES02usly6UXgMh6sl`.
The event has only `active`, `created_at`, `environment`, `name`: all three required
configuration fields (`starts_at`, `ends_at`, `registration_periods`) are absent.
No event update was performed.

All **17** existing Active Event registrations lack all four new retention fields.
None can be safely migrated from the inspected data: created/photo timestamps do
not establish an approved period choice or historical event options. None was
migrated, made eligible or deleted. Ten have a photo path and seven do not; a path
alone is not proof of Storage availability. These are legacy test-data limitations.

The separate local audit `/tmp/radd-registration-retention-audit.json` lists every
exact document path and its missing fields without names/contact data. This artifact
is outside Git. No Firebase writes were made by the audit.

After configuring the event, use the corrected Guardian flow to create a **new
explicitly approved test registration** with a real captured photograph. Leave the
period selection at default to verify longest-valid behavior; optionally create a
second test registration choosing the shorter period. Verify the new stored expiry,
then open Volunteer Report → Manual Review with an assigned Active Volunteer:
those new eligible registrations should appear with name/gender search and filters.
The 17 legacy records must not be made valid merely to populate that list. Standalone Found Report verification/handover is now supported without a Missing
Case; see [the standalone flow](standalone-found-reports.md).

## Validation and changed files

Full Flutter suite: 200 passing. Flutter analyze: no issues. Android debug APK built
at `build/app/outputs/flutter-apk/app-debug.apk`, with local development URL
`http://127.0.0.1:8000` (requires adb reverse on emulator); not installed as part of
this pass. Gradle reports the existing Kotlin plugin migration advisory.
Full backend suite: 187 passing (56 existing SDK deprecation warnings).
`git diff --check` passed. CLI `--help` verified without Firebase mutation.
No live destructive cleanup or newly configured registration test was performed.

Retention-specific files changed/added:

- Backend: `app/registration_retention.py`, `app/service.py`, `app/models.py`,
  `app/main.py`, `app/cases.py`, `app/volunteer.py`, `app/volunteer_workflow.py`,
  `app/cleanup.py`, `scripts/configure_registration_periods.py`, `README.md`.
- Flutter: Guardian repository/API, individual form, `case_widgets.dart`; both ARB
  files and regenerated localization Dart files. Arabic and English privacy text
  now distinguish registered data from Found Report photographs. Expired profile
  action opens a new registration instead of implying retake renews expiry.
- Tests: backend registration-retention suite and event fixtures/old lifetime tests
  (`firestore_fake`, `test_crud`, `test_cases`, `test_fcm`, `test_retention`,
  `test_volunteer`, `test_volunteer_workflow`, `test_guardian`); Flutter Guardian
  form/flow regression tests and fake repository contract.

Other working-tree changes predate this retention task and were preserved.

Standalone identified Found Reports now also defer deletion while verification/handover
is pending, without changing expiry or general eligibility. See
[standalone Found Reports](standalone-found-reports.md) for the approved minimal
completed-report record and context-specific access.

The consolidated stabilization report (`volunteer-stabilization-final-report.md`)
supersedes earlier eligibility descriptions: Missing Case holds are now explicitly
opted into for existing case context, never general Manual Review eligibility.
