# Manual Firebase Admin setup for local Radd verification

The backend needs a server identity for the existing **radd-32eb6** project. Android's `android/app/google-services.json` is client configuration, not an Admin credential. No private key was created, downloaded, read, or committed during this implementation. For the latest live results and remaining device checks, see [the runtime integration report](volunteer-realtime-report.md).

## Preferred setup: keyless local ADC

Use Application Default Credentials (ADC) with **service-account impersonation**. Google documents support for Python. A project administrator must authorize your Google account to impersonate the selected backend service account. The resulting ADC file contains sensitive login material, but no downloaded service-account private key; keep it outside the repository and never paste its contents into chat.

1. Install the Google Cloud CLI yourself. Select project `radd-32eb6` in Google Cloud Console.
2. Select an appropriate existing backend service account, or have your project administrator create a dedicated one manually. Do not create a JSON key. Verify it belongs to `radd-32eb6`.
3. Have the administrator grant the backend service account the required product access. For this repository's current operations, useful predefined roles are:

   | Resource | Role | Purpose |
   | --- | --- | --- |
   | Project | `roles/firebaseauth.viewer` | Read accounts during revoked/disabled-token validation; the app signs users in through the Firebase client SDK. |
   | Firestore database/project | `roles/datastore.user` | Read/write shared users, registrations, cases, notifications, and retention records. |
   | Project | `roles/firebasecloudmessaging.admin` | Send FCM messages. |
   | Existing Radd Storage bucket | `roles/storage.objectAdmin` | Read/upload/delete photographs. Scope this to the bucket, not unrelated projects/buckets. |

   These are product-level predefined roles, not a claim of a custom minimal-permission policy. No Owner/Editor role is needed for the backend. No permission to create authentication users is required by its current routes; development accounts are manually created in Firebase Authentication and provisioned using the existing script.
4. Grant **your Google user** `roles/iam.serviceAccountTokenCreator` on that specific service account. The administrator must enable `iamcredentials.googleapis.com` and `fcm.googleapis.com` if absent. Ensure Firestore, Firebase Authentication and the existing Storage bucket are provisioned. If quota-project setup is denied, ask for `serviceusage.services.use` on this project; do not grant broad administrative access as a workaround.
5. Run these commands yourself, replacing `BACKEND_SERVICE_ACCOUNT_EMAIL` with the real selected service-account email:

   ```bash
   gcloud auth login
   gcloud config set project radd-32eb6
   gcloud auth application-default login --impersonate-service-account=BACKEND_SERVICE_ACCOUNT_EMAIL
   gcloud auth application-default set-quota-project radd-32eb6
   ```

6. In the terminal used for the local backend, unset any previously set key-file override, then run from the repository root:

   ```bash
   unset GOOGLE_APPLICATION_CREDENTIALS
   backend/.venv/bin/python backend/run_dev.py --adc
   ```

   `--adc` uses your manually configured ADC; it does not initiate login or create/download a key. The startup check rejects service-account identities from other projects. The local runner enables approved one-minute retention and Volunteer alert-retry jobs. Keep one local server instance running. Starting it allows those jobs to act on real data in the configured project; stopping it stops periodic processing. A job's failure is logged and retried, not reported as success. The 24-hour sweep can run up to one interval later while the server is healthy, and later still if it was offline or a dependency failed.

7. The existing composite index in `firestore.indexes.json` (`cases`: status + closed_at) is required for terminal-case retention. Have the project administrator deploy that index manually if it is not already present. No index, security-rule, IAM, or cloud deployment was performed by this task.

## Actual verification still needed

A successful `/health` response only proves the HTTP server is running. It does **not** verify Firebase connectivity or FCM delivery.

Use real development accounts in this same project: one Guardian and two enabled Volunteers with matching `users/{uid}` profiles and one active event. Do not paste passwords or Firebase ID tokens into chat. Do not bootstrap a new event over the team's existing event. The existing `backend/scripts/provision_volunteer.py` documents the profile setup for an already-created Firebase Auth UID.

For this local Pixel 7 development setup, use the existing configurable API URL through ADB. Live diagnosis found intermittent requests taking more than 31 seconds to reach FastAPI through the emulator's `10.0.2.2` bridge. The same backend responds through the ADB route without that bridge. This does not change Firebase, authentication or either role's API routes.

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 reverse tcp:8000 tcp:8000
flutter run -d emulator-5554 --dart-define=RADD_API_URL=http://127.0.0.1:8000
```

Use the actual device serial from `adb devices` if different. Repeat `adb reverse` after restarting the emulator/device. The installed debug APK retains its compiled API URL, but a later plain `flutter run` without the define builds with the existing `10.0.2.2` default again. A USB-connected physical device can use the same forwarding technique with its serial. Release URLs must still use HTTPS.

As confirmed on 2026-09-21, Volunteer FCM delivery requires an unexpired registered Firebase ID token and a non-disabled, non-revoked Firebase Auth session. The app listens to Firebase ID-token changes and automatically renews the device/session association during legitimate signed-in use; normal refresh does not require notification permission to be enabled again. Logout closes registration and deletes the local FCM token. A new login registers again. While the app cannot run to renew an expired registration, pushes remain stopped; history remains available, and eligible pending events are retried after authenticated renewal. The backend checks the server-verified `auth_time` against Firebase Auth's revocation boundary before sending. It fails closed if that check is unavailable.

For the reported two-user delay, effective backend addresses, T0–T9 logging and the controlled create/cancel/resolve protocol, see [realtime-controlled-test.md](realtime-controlled-test.md). A separate emulator's `10.0.2.2` points to its own host, not automatically to this Mac.

Verify real login/reset email, Guardian case creation, both Volunteer joins, foreground and background FCM delivery, notification taps, camera preview/retake/use, real manual review, contact access, immediate photo deletion after match, QR/alternative verification and handover. Test denied location separately: general alerts remain available, priority is absent. Verify priority with actual permitted device location within 500 m of the Guardian-confirmed last-seen coordinates. Do not use simulated positions as proof of physical-device behavior.

The FCM path uses the existing project and named Firebase Admin app. Backend dispatch tests replace the network sender; they are not evidence that an actual phone received a message. Firebase/Google Cloud APIs, IAM grants, device notification permission, Google Play services, and network availability must all be verified in the real environment.

## Official references

- [Firebase Admin setup](https://firebase.google.com/docs/admin/setup)
- [Local ADC and service-account impersonation](https://docs.cloud.google.com/docs/authentication/set-up-adc-local-dev-environment)
- [Firebase Authentication and FCM IAM roles](https://firebase.google.com/docs/projects/iam/roles-predefined-product)
- [Firestore access control](https://docs.cloud.google.com/firestore/native/docs/security/iam)
- [Storage IAM roles](https://docs.cloud.google.com/storage/docs/access-control/iam-roles)
