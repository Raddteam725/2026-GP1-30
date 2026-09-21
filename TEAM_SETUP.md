# Running the shared Radd app and backend

Use your own clean checkout. Preserve local changes before switching branches; do not discard a stash or reset shared work.

```powershell
git fetch origin
git switch --track origin/lateef/guardian-sprint0-integration
flutter pub get
```

If the local branch already exists, switch to it normally. Do not merge or push main as part of these steps.

## Shared backend
Python 3.11+ is required. Create a local virtual environment:
```powershell
py -m venv backend/.venv
backend/.venv/Scripts/python -m pip install -r backend/requirements.lock
```

Use an individually provisioned service account for the SAME Firebase project, radd-32eb6, with the required Firebase Auth verification, Firestore and Storage permissions. Keep its JSON OUTSIDE the repository. Never share private JSON through Git, chat, or a pull request.

Start the API:
```powershell
backend/.venv/Scripts/python backend/run_dev.py --credentials-dir 'C:\secure\FirebaseKeys'
```

The directory must contain exactly one JSON file. Alternatively supply GOOGLE_APPLICATION_CREDENTIALS in the backend terminal's process environment. The launcher also detects a single key in Desktop/FirebaseKeys, including redirected OneDrive desktops. It rejects files inside the repository and credential/project mismatches. It does not modify machine environment variables or copy the key.

On this development machine, the existing ignored embedded Python can also run the launcher:
```powershell
backend/.tools/python/python.exe backend/run_dev.py
```

The server binds 127.0.0.1:8000. GET http://127.0.0.1:8000/health returns 200 for liveness. It is NOT proof of authenticated cloud access. Do not run a second server on that port.

## Normal Android app
```powershell
flutter run -d emulator-5554 -t lib/main.dart
```

Use the device ID from flutter devices if different. Debug API requests use the centralized http://10.0.2.2:8000 host bridge in GuardianApi. Do not use localhost inside Android. A different HTTPS service can be supplied with --dart-define=RADD_API_URL=https://your-approved-host. Release builds require HTTPS.

**Two-user test (Guardian + Volunteer on different devices/computers):** `10.0.2.2` only ever reaches the computer running *that* emulator, so two developers each running `run_dev.py` are on two separate backends that merely share Firestore. Both apps must point at ONE FastAPI process. On one Wi-Fi network: start it with `backend/.tools/python/python.exe backend/run_dev.py --host 0.0.0.0` on one PC (its firewall must allow port 8000) and build BOTH apps (debug) with `--dart-define=RADD_API_URL=http://<that PC's LAN IPv4>:8000`. Never commit an address; the final deployment replaces this with one HTTPS Cloud Run URL in the same define. The push/refetch path and the `Radd timing:` T1–T8 log lines are documented in backend/README.md ("Real-time contract").

Use lib/main.dart. The opt-in test/guardian_runtime_app.dart is an isolated UI fixture and must never be used as a production demonstration.

## Contracts and ownership
- One Firebase project, Auth service and FastAPI app serve the team.
- GET /v1/session verifies the Firebase token, then resolves server-owned role data.
- Guardian profiles: users/{firebaseUid}; no client-supplied UID is trusted.
- Registered individuals: users/{firebaseUid}/individuals/{id}.
- Private photos: guardians/{firebaseUid}/individuals/{id}/{random}.jpg, accessed through the authenticated API.
- Canonical email comes from Firebase identity; editable profile fields are full_name and phone.
- Existing Volunteer custom claims (role=volunteer, enabled=true, nonempty volunteerId) remain the Volunteer team's contract. This branch does not provision Volunteer accounts or change its feature logic.
- A missing Guardian profile can be completed for an existing Auth account without duplicate registration.
- Signed-out startup and logout retain language but return through Language/Role selection.
- No case, QR, reporting or AI feature is added by this Guardian integration.

## Checks
```powershell
flutter gen-l10n
flutter analyze
flutter test
backend/.venv/Scripts/python -m pytest backend/tests -q -o cache_dir=backend/.pytest_cache
```

Each developer must also test the normal Android app against the real backend. In-memory unit tests do not prove cloud persistence. Camera tests require a working device/emulator camera source; no gallery alternative is provided.

To exercise the Guardian screens for the Volunteer-driven stages (Search in Progress, Match Confirmed, Awaiting Guardian Verification, Reunited) before the Volunteer app is integrated, advance a real development-event case with `backend/scripts/dev_case_state.py` (see backend/README.md, "Development case-state command"). It writes the same canonical fields the Volunteer workflow writes and refuses non-development events.

## Team Git rules
Work only on your feature branch. Preserve lateef-guardian-backup and existing stashes. Push only the feature branch without force; open a pull request for review. Do not automatically merge to main. Shared backend changes must be coordinated with the Volunteer owner.
