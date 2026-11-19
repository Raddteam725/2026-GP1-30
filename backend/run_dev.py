"""Start the shared local API with credentials kept outside this repository."""
import argparse
import os
import sys
from pathlib import Path

def configure_credentials(directory=None):
    root = Path(__file__).resolve().parents[1]
    if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        credential = Path(os.environ["GOOGLE_APPLICATION_CREDENTIALS"]).expanduser().resolve()
    else:
        folders = [Path(directory).expanduser()] if directory else [Path.home() / "Desktop" / "FirebaseKeys"]
        if not directory:
            one_drive = Path(os.getenv("OneDrive", str(Path.home() / "OneDrive")))
            if one_drive.is_dir():
                folders.extend(child / "FirebaseKeys" for child in one_drive.iterdir() if child.is_dir())
        matches = {file.resolve() for folder in folders if folder.is_dir() for file in folder.glob("*.json")}
        if len(matches) != 1:
            raise RuntimeError("Set GOOGLE_APPLICATION_CREDENTIALS or pass --credentials-dir containing exactly one service-account JSON.")
        credential = matches.pop()
    if not credential.is_file() or credential.is_relative_to(root):
        raise RuntimeError("Credentials must be an existing file outside the repository.")
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(credential)

def validate_credential_project(credential, project_id):
    credential_project = getattr(credential, 'project_id', None)
    service_email = getattr(credential, 'service_account_email', '')
    if credential_project == project_id or service_email.endswith('@' + project_id + '.iam.gserviceaccount.com'):
        return
    raise RuntimeError('Use credentials for a service account in the configured Radd project.')

def configure_local_jobs(enabled):
    # Overrides any shell value: --local-jobs is the only way to turn them on.
    os.environ["RADD_LOCAL_JOBS"] = "1" if enabled else "0"
    print("Local maintenance jobs: " + ("ON" if enabled else "OFF (pass --local-jobs to enable)"))
    if enabled:
        print("WARNING: cleanup deletes data in the shared Firebase project. Use --local-jobs only deliberately.")

def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials-dir")
    parser.add_argument("--adc", action="store_true", help="Use manually configured keyless service-account ADC; do not discover JSON keys.")
    parser.add_argument("--port", type=int, default=int(os.getenv("PORT", "8000")))
    # Loopback by default. For a two-device test on one Wi-Fi network run with
    # `--host 0.0.0.0` and build BOTH apps with --dart-define=RADD_API_URL=
    # http://<this PC's LAN address>:8000 -- no address is ever hardcoded here.
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--bootstrap-event", action="store_true")
    parser.add_argument("--local-jobs", action="store_true", help="Run retention cleanup and push retries in this process (deletes shared data).")
    return parser

def main():
    args = build_parser().parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        if args.adc:
            if args.credentials_dir or os.getenv('GOOGLE_APPLICATION_CREDENTIALS'):
                raise RuntimeError('For keyless ADC, omit --credentials-dir and unset GOOGLE_APPLICATION_CREDENTIALS.')
        else:
            configure_credentials(args.credentials_dir)
        from app.firebase import firebase_app
        app = firebase_app()
        credential = app.credential.get_credential()
        validate_credential_project(credential, app.project_id)
    except Exception as error:
        # Do not print credential paths, JSON, tokens, or exception payloads.
        raise SystemExit("Firebase Admin setup failed (" + type(error).__name__ + "). Check the external credential configuration.")
    if args.bootstrap_event:
        from app.firebase import database
        from app.events import bootstrap_development_event
        bootstrap_development_event(database())
        print("Current development event is ready.")
    # Optional LOCAL maintenance thread: retention cleanup and push retries
    # every minute, OFF unless --local-jobs is passed, because cleanup deletes
    # data in the shared Firebase project. The deployed service never runs it;
    # maintenance runs as separate Cloud Run Jobs (see app/jobs.py).
    configure_local_jobs(args.local_jobs)
    import uvicorn
    uvicorn.run("app.main:app", host=args.host, port=args.port, access_log=False)

if __name__ == "__main__":
    main()
