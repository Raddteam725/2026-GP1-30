# Radd — رادّ

**AI-Based Lost Person Identification and Family Reconnection System for Crowded Events**

Graduation Project (IT496) · College of Computer and Information Sciences, King Saud University

---

## About

At large crowded events, families get separated — and the people most at risk are often the least able to identify themselves, such as young children and elderly individuals.

Radd helps reconnect them. Guardians register the individuals under their care before the event. If someone goes missing, the guardian reports it from the app and authorized volunteers are alerted. When a volunteer finds a separated individual, the system uses AI to help identify who they are and connect them back to their guardian, with a verification step before handover.

Radd consists of a mobile application for guardians and volunteers, and a web portal for event administrators.

---

## What It Does

- Register individuals before the event
- Report a missing person in one step
- Alert volunteers across the event in real time
- AI-assisted identification of found individuals
- Verify the guardian before handover
- Available in Arabic and English

Personal data is kept only for as long as it is needed and is deleted automatically afterwards.

---

## Technologies

| Area | Technology |
|---|---|
| Mobile application | Flutter · Dart (Android) |
| Backend API | Python 3.11+ · FastAPI · Uvicorn |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| File storage | Firebase Cloud Storage |
| Notifications | Firebase Cloud Messaging |
| Testing | flutter test · pytest |

---

## Running the Project

Full instructions, including credentials and two-device testing, are in **[TEAM_SETUP.md](TEAM_SETUP.md)**.

**Requirements:** Flutter SDK, Android Studio with an emulator or a physical Android device, Python 3.11 or later, and access to the project's Firebase instance.

**1. Install dependencies**

```bash
flutter pub get
py -m venv backend/.venv
backend/.venv/Scripts/python -m pip install -r backend/requirements.lock
```

**2. Provide Firebase credentials**

The backend needs a Firebase service-account key. Keep the JSON file **outside** the repository and point the launcher at its folder.

**3. Start the backend**

```bash
backend/.venv/Scripts/python backend/run_dev.py --credentials-dir "<folder containing the key>"
```

The API runs on port 8000. Check `http://127.0.0.1:8000/health` in a browser — it returns `{"status":"ok"}` when the server is up.

**If the app shows "The service is currently unavailable"** while the backend is clearly running, the emulator cannot reach it. Add `--host 0.0.0.0` to the command above and allow the connection if Windows Firewall prompts. This depends on your machine's network configuration, so it is not needed on every setup.

**4. Run the app**

```bash
flutter run -d <device-id> -t lib/main.dart
```

Use `flutter devices` to list available devices. Android emulators reach the local backend through `10.0.2.2:8000`.

**Running the tests**

```bash
flutter analyze
flutter test
backend/.venv/Scripts/python -m pytest backend/tests -q
```

---

## Repository Structure

| Path | Contents |
|---|---|
| `lib/` | Flutter application source |
| `backend/` | FastAPI backend and its tests |
| `test/` | Flutter widget and unit tests |
| `docs/` | Development and verification notes |
| `assets/` | Images and static assets |

---

## Team

See [AUTHORS](AUTHORS.md).

**Supervisor:** Dr. Henda Ouertani

King Saud University · College of Computer and Information Sciences · Department of Information Technology
