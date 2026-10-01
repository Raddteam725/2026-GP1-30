# Historical Volunteer assignment proposal — superseded

The user subsequently approved **document existence** as assignment, without
an `assigned` Firestore field. The implementation and current testing commands
are documented in [volunteer-event-assignment.md](volunteer-event-assignment.md).
The text below records the earlier proposal, not the current implementation.

This proposal awaits review. No Firestore data, assignment schema, or assignment
authorization has been changed.

## Existing structures

- `users/{uid}` is the reusable account: `role: volunteer`, `active`,
  `full_name`, `volunteer_id`, email and phone.
- `events/{eventId}` already defines events; `active_event()` requires exactly
  one event with `active == true`.
- Cases, found reports and Guardian individual registrations already carry
  `event_id`.
- `users/{uid}/fcm_registrations/{tokenHash}.event_id` is a device/session
  registration attribute, not an administrative assignment. It cannot serve
  as proof of assignment.
- Flutter does not access Firestore/Storage directly. Existing rules deny
  direct client access; shared FastAPI authorizes Admin SDK operations.

## Smallest proposed addition

Document: `events/{eventId}/volunteers/{uid}`.

| Field | Type | Meaning |
| --- | --- | --- |
| `assigned` | Boolean | True when currently assigned; false after removal |
| `updated_at` | Timestamp | Server time of the latest assignment change |
| `updated_by` | String | UID of the authenticated administrator making the change |

Event ID and Volunteer UID come from the path. Do not duplicate names, account
status, phone numbers, or Volunteer IDs in this document. Missing documents
mean unassigned. Reassignment updates the same document. A later event uses
the same user account and a separate assignment document.

This is current-state metadata, not a full audit trail. No audit-history
collection or Admin Portal is proposed for this task.

## Proposed enforcement after approval

1. Keep account authentication/profile access separate from event authorization.
   An enabled but unassigned Volunteer can view their own profile/ID and log out.
2. For event operations, require an authenticated, enabled Volunteer, the single
   Active event, and `assigned == true` for that event. Recheck on the backend,
   including mutation transactions and queued notification delivery.
3. Assignment/removal during an Active event updates this document without
   changing `users.active`, Guardian cases, joined history or found reports.
4. The Digital ID derives authorization from account/event/assignment state;
   no client-editable authorization flag. Unassigned shows the specified red
   indicator; assigned authorization uses the green animation. Inactive
   accounts still follow the existing deactivation/logout behavior.
5. Reuse existing authoritative refresh and notification delivery mechanisms
   to invalidate access on assignment removal/event changes. Do not create
   another listener architecture or extend authenticated session expiry.
6. Existing Volunteers do **not** become assigned automatically. Before testing
   assignment enforcement, an administrator must explicitly assign test users.
   No production documents will be manufactured or silently migrated.

## Location boundary dependent on assignment

The Android implementation should use the installed Geolocator location
foreground service, started while the app is visible after permissions and
event authorization are established. Keep a localized ongoing notification
and declare the location foreground-service permissions. Do not add an End
Participation UI or start the service from arbitrary background callbacks.

Stop location on logout, account/access loss, assignment removal, event end,
permission revocation or disabled services. Suspend event workflow and device
alert eligibility when permission/services are missing. An unavailable or
inaccurate estimate alone must not suspend participation/general alerts.

Assignment-based start/stop and Digital ID enforcement remain pending this
schema decision. `VolunteerLocation.authorizeBackgroundParticipation()` now
prepares the Android foreground service and localized notification configuration,
with ongoing notification, wake lock and a dedicated notification icon. It must
be called only after backend event authorization, while the activity is visible.
It is deliberately not called by the workspace until that contract is approved.
The running application therefore still stops location on backgrounding; this
is not a completed end-to-end background-location implementation.

Implemented independently of that schema:

- An explicit permission explanation precedes the first OS permission request.
- Volunteer event UI/actions are gated on permission and enabled device services;
  the profile, logout and current ID screen remain accessible. ID assignment
  semantics still await the schema.
- Service-disable events immediately cancel location; resume rechecks permission.
  Temporary missing/inaccurate fixes do not revoke access. Late callbacks cannot
  restore a stopped/disposed subscription.
- Logout stops location before awaiting network/auth cleanup.
- Missing location access unregisters this session's FCM device association;
  restored access re-registers it without requiring a new notification permission.
  No estimate still permits general push registration. Existing durable history
  and server recipient/assignment enforcement are not replaced by this client gate.
- Background FGS behavior is covered at the platform-adapter test boundary.
  Physical-device checks remain required after assignment wiring. Geolocator's
  foreground service does not guarantee continued Dart execution after Android
  destroys the process; no automatic background restart is introduced.
- The authenticated Volunteer profile response includes
  `proximity_radius_meters` from the existing shared backend constant (500).
  Flutter uses that value for nearby case presentation.

Android references:
- https://developer.android.com/training/permissions/requesting
- https://developer.android.com/develop/background-work/services/fgs/launch
- https://pub.dev/documentation/geolocator/latest/

## Independent Manual Review implemented alongside this proposal

AI-assisted identification remains the primary operational path after submitting
a Found Report. Manual Review is the operational fallback when AI does not
produce a reliable result, but its secondary UI entry is independently
accessible and never requires a recorded AI failure. This does not promote
Manual Review to an equal default identification method. The actual AI engine
remains postponed; its unavailable state must be truthful.

Home now opens Manual Review without an AI attempt or a Found Report. Browse,
search, filter and profile details use existing event-scoped endpoints.
Unrestricted profile details no longer return Guardian contact information.

The existing detail endpoint accepts an optional `found_report_id` or `case_id`:
the server validates ownership/current event and active state before returning
contact. Ordinary independent browsing sends neither. The existing report
workflow supplies its real report ID. Confirm Match still requires the existing
real report workflow; browsing does not fabricate a report or bypass QR/handover.
