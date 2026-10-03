# Radd team setup

Radd has a Flutter app for Guardian and Volunteer and a FastAPI backend. Both backend modes use the existing Firebase project `radd-32eb6`.

Run commands from the repository root. Use your own assigned feature branch and preserve local changes and stashes before switching branches.

```powershell
flutter pub get
```

## LOCAL DEVELOPMENT MODE

Use this mode when developing against FastAPI on your own computer. Python 3.11+ is required; the commands below select Python 3.11.

Create the virtual environment and install the authoritative locked dependencies:

```powershell
py -3.11 -m venv backend\.venv
backend\.venv\Scripts\python -m pip install -r backend\requirements.lock
```

Keyless local Application Default Credentials (ADC) is the preferred credential method; follow [docs/firebase-local-setup.md](docs/firebase-local-setup.md). Never commit or share credentials or place them inside the repository.

After configuring keyless ADC, start FastAPI in a PowerShell terminal:

```powershell
backend\.venv\Scripts\python backend/run_dev.py --adc --host 127.0.0.1 --port 8000
```

`backend/run_dev.py` keeps local maintenance jobs OFF by default. Normal local development must **not** use `--local-jobs`. This flag is explicit opt-in only and may run cleanup/maintenance against the configured Firebase project; do not enable it casually.

An external Firebase Admin service-account JSON for `radd-32eb6` remains a supported local alternative. Keep it outside the repository, for example in `C:\secure\FirebaseKeys`, with exactly one JSON key file in that directory. Start through `run_dev.py`:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = (Get-ChildItem "C:\secure\FirebaseKeys" -Filter *.json).FullName
backend\.venv\Scripts\python backend/run_dev.py --host 127.0.0.1 --port 8000
```

This environment variable exists only in that terminal session and is inherited by processes started there. It does not change machine or user environment settings; closing the terminal removes it.

In a separate terminal, forward the Android port and start the normal Flutter app:

```powershell
adb devices
adb -s <device-id> reverse tcp:8000 tcp:8000
flutter run -d <device-id> --dart-define=RADD_API_URL=http://127.0.0.1:8000
```

Replace `<device-id>` with the actual Android device/emulator ID from `adb devices`. `adb reverse` forwards port 8000 from the Android device/emulator to the developer computer's local FastAPI server at `127.0.0.1:8000`. Both Guardian and Volunteer use the supplied `RADD_API_URL`.

Use the planned shared mode below for team testing across devices and computers once it is available.

`GET http://127.0.0.1:8000/health` checks liveness only. A successful response does **not** prove Firebase connectivity or authenticated Firestore/Storage access.

## SHARED DEVELOPMENT MODE

**Status: architecture and shared deployment approved; the backend is not deployed yet and the final HTTPS URL is not available yet.**

The target is one hosted FastAPI backend on Google Cloud Run, with service name `radd-api-dev`. It will use the same Firebase project, `radd-32eb6`; no Firebase migration or second Firebase project is needed.

Once the real HTTPS URL is available, replace the placeholder below and start Flutter:

```powershell
flutter run --dart-define=RADD_API_URL=https://<shared-radd-dev-backend>
```

`https://<shared-radd-dev-backend>` is a placeholder, not a working endpoint. Guardian and Volunteer both use `RADD_API_URL`; the shared URL must use HTTPS. Developers using shared mode do not run a local FastAPI server, need no `adb reverse`, and do not need devices on the same Wi-Fi.

FastAPI remains the authoritative protected API and business layer. Firebase Auth tokens continue to authenticate requests, and protected Firestore/Storage business access remains server-side.

Cloud Run will use its service identity and Application Default Credentials. No service-account JSON belongs in Flutter, Docker, GitHub, or the deployed container; do not set `GOOGLE_APPLICATION_CREDENTIALS` for the shared service.

The Cloud Run web service uses inline delivery. `RADD_LOCAL_JOBS` must not run in the Cloud Run web service; maintenance retry and cleanup run as separate hosted jobs once cloud deployment is configured.

FCM remains notification infrastructure; notifications are not authoritative state. When a notification is received or the app resumes/reconnects, authoritative state comes from FastAPI.

Deployment commands and confirmed deployment details will be documented in `docs/shared-dev-deployment.md` after the real deployment.

## Checks

```powershell
flutter gen-l10n
flutter analyze
flutter test
```

For backend changes, use the local Python environment:

```powershell
backend\.venv\Scripts\python -m pytest backend/tests -q -o cache_dir=backend/.pytest_cache
```

Test the normal app through `lib/main.dart` against the chosen backend mode. In-memory unit tests and `/health` do not prove cloud persistence. Camera tests require a working device/emulator camera source.

## Team Git workflow and ownership

- Each developer works on their own assigned feature branch.
- Preserve local changes and existing stashes; do not discard shared work.
- Push feature branches without force-pushing and open PRs for review.
- Do not automatically merge to `main`.
- Leen owns Deployment & Environment. Tala owns Notifications & Background Jobs. Shared-backend changes across these areas must be coordinated between them.
