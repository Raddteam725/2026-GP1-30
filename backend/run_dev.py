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

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials-dir")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        configure_credentials(args.credentials_dir)
        from app.firebase import firebase_app
        app = firebase_app()
        credential = app.credential.get_credential()
        if getattr(credential, "project_id", None) != app.project_id:
            raise RuntimeError("Credential project does not match the configured Radd project.")
    except Exception as error:
        # Do not print credential paths, JSON, tokens, or exception payloads.
        raise SystemExit("Firebase Admin setup failed (" + type(error).__name__ + "). Check the external credential configuration.")
    import uvicorn
    uvicorn.run("app.main:app", host="127.0.0.1", port=args.port, access_log=False)

if __name__ == "__main__":
    main()
