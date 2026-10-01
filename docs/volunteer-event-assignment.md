# Volunteer event assignment and participation

## Approved data contract

`events/{eventId}/volunteers/{uid}` exists = assigned. Absence = unassigned.
The document written by the service contains only `updated_at` (server
Timestamp) and `updated_by` (operator identifier). There is no `assigned`
Firestore field. The API derives its `assigned` Boolean from existence.

`users/{uid}.active` remains the independent Boolean account switch. Assignment
does not enable an account; deactivation does not remove assignment. The shared
backend still requires exactly one Active event. An account assigned only to
another event cannot participate in the current event.

No account was assigned, removed, enabled or deactivated in real Firebase by
this implementation task. Existing users need explicit assignment before their
next event workflow request. No implicit migration or automatic assignment runs.

## Shared business/security boundary

`backend/app/volunteer_access.py` centralizes assignment lookup, event eligibility
and `VolunteerManagement.change()` operations: assign, remove, enable, deactivate.
The development CLI calls this same service. A Sprint 5 Admin API can call it
after authorizing the authenticated administrator and supplying that actor's
UID. It must not trust an actor UID supplied by an ordinary client. No public
management endpoint or Admin screen is added now.

Event endpoints require an enabled account and current assignment, including
transactional joins/match/verification/handover, profiles/photos/contact,
reports, notifications and device registration. The own-account profile and
device unregistration remain accessible without assignment. Inactive account
requests retain the existing shared logout flow.

The Android app separately checks permission and device location services;
the backend cannot independently attest Android permissions. Loss of location
access unregisters the device's alert association. Durable history is retained;
unassigned accounts cannot read event history. Notification fan-out and queued
delivery recheck current assignment/account eligibility. Existing notification
IDs and Guardian case semantics are preserved. Firestore/Storage client rules
remain deny-direct-access.

The Digital ID shows event authorization with green animation or a red
unassigned indicator, plus separate account status. The profile and ID remain
available for an enabled, unassigned user.

## Location and revocation

The location service starts only in a visible Activity after API authorization
and granted location permission/services. It uses Geolocator's Android location
foreground service, a localized ongoing notification, wake lock and an explicit
location notification icon. There is no End Participation button and no
unrestricted background/boot startup permission.

Temporary missing/inaccurate coordinates do not remove participation or general
alert access. Background fixes request a 20-second interval without a movement
threshold; fixes older than 60 seconds are excluded from local proximity use.
The backend retains its existing 60-second location freshness rule. Android
can throttle requested intervals; these are not delivery guarantees.

The existing 20-second recovery check also runs while the location service is
active, rechecking permission/services and authoritative account/event state.
Foreground management changes send a non-sensitive `role=volunteer`,
`kind=access_changed` hint that starts a dedicated profile refresh. It contains
no case/profile/contact data, is not a case notification and does not create
notification history. A dropped hint falls back to periodic/resume recovery.

Unassignment, event end/change or deactivation stops location, clears protected
event state and prevents further workflow access. Backend authorization takes
effect on the next request/queued-delivery check. Client revocation detection
depends on delivery or the recovery interval plus network time; it is not an
instant offline remote kill switch. Logout stops location before network cleanup.
After reactivation, a user logged out by deactivation must log in again.

Android may stop the process/foreground service. No fake location or automatic
background restart is introduced. Reopening the app revalidates participation
before restarting. Physical-device validation is still required.

## Development operations (no Admin UI)

After updating backend code, restart the local FastAPI process before testing.
Restarting Flutter or logging out/in does not reload Python modules in an
already-running Uvicorn process without reload enabled. A pre-assignment backend
can return a successful profile response without `assigned` / `event_id`; the
client deliberately treats missing authorization fields as unauthorized.
During the September 28 runtime check, restarting the September 21 backend
process restored the existing test assignment in the Digital ID without any
Firestore assignment changes.

Run from the repository root with the existing authorized ADC configuration.
Do not download keys. The CLI requires `--project` to match
`FIREBASE_PROJECT_ID` (default `radd-32eb6`) and refuses non-Volunteer accounts.
It changes Firestore account status, not Firebase Auth passwords, identity or
Auth `disabled`. It creates no Authentication account and never touches Guardian
data. Assignment removal deletes only the exact assignment document; it does
not delete a user or case.

Find the existing event ID in Firebase Console → Firestore → `events`: the
current event has `active: true`. Use an existing Volunteer UID from Firebase
Authentication whose `users/{uid}` profile has `role: volunteer`.

Set these shell variables to your actual identifiers:

```sh
RADD_TEST_UID='EXISTING_VOLUNTEER_UID'
RADD_TEST_EVENT='EXISTING_EVENT_ID'
RADD_OPERATOR='YOUR_OPERATOR_IDENTIFIER'
```

Preview assignment (read-only):

```sh
backend/.venv/bin/python backend/scripts/manage_volunteer.py assign --uid "$RADD_TEST_UID" --event-id "$RADD_TEST_EVENT" --actor "$RADD_OPERATOR" --project radd-32eb6
```

After reviewing the target, execute one chosen operation:

```sh
backend/.venv/bin/python backend/scripts/manage_volunteer.py assign --uid "$RADD_TEST_UID" --event-id "$RADD_TEST_EVENT" --actor "$RADD_OPERATOR" --project radd-32eb6 --apply
backend/.venv/bin/python backend/scripts/manage_volunteer.py remove --uid "$RADD_TEST_UID" --event-id "$RADD_TEST_EVENT" --actor "$RADD_OPERATOR" --project radd-32eb6 --apply
backend/.venv/bin/python backend/scripts/manage_volunteer.py enable --uid "$RADD_TEST_UID" --actor "$RADD_OPERATOR" --project radd-32eb6 --apply
backend/.venv/bin/python backend/scripts/manage_volunteer.py deactivate --uid "$RADD_TEST_UID" --actor "$RADD_OPERATOR" --project radd-32eb6 --apply
```

Each command without `--apply` is a preview. Do not run all four consecutively
unless that is the test you intend. Removing an already absent assignment is
idempotent; reassigning updates the audit metadata. Removal has no remaining
assignment document by design; this minimal schema is not a full audit log.

## Device test sequence

1. Enable and assign the test Volunteer. Log in, allow location, keep services
   enabled. Check Home, real cases and the green current-event ID.
2. Background the app. Verify the persistent location notification and valid
   nearby alert updates while a real Guardian creates a relevant case.
3. Remove assignment with the command while participating. Check that event
   access is blocked, ID is red, and the location notification/subscription stops.
   `users.active` and real cases must remain unchanged.
4. Reassign while enabled. In the foreground, access should restore after the
   access hint or periodic refresh, without creating another Auth account.
5. Deactivate while assigned. Verify shared logout and stopped location. The
   assignment document must still exist. Re-enable and log in again.
6. Disable device location services, then restore them. Check blocking/restoration.
   Revoke permission in Android Settings and repeat. Logout must stop the service.
7. With permission/services enabled, temporarily unavailable GPS must allow
   participation/general alerts, but no proximity eligibility until a good fix.
8. End the event in a controlled test environment; verify no event access and
   stopped tracking. Do not toggle a real ongoing event merely to test this.

AI/Manual Review, real camera/report, QR and handover behavior is unchanged.
Actual AI matching remains intentionally unimplemented.
