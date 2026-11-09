"""Download the face-recognition model used by app/face_matching.py (configuration C7).

Source: InsightFace's official GitHub release v0.7, model pack "buffalo_l" (275 MB zip).
Only the recognition model w600k_r50.onnx (166 MB) is kept, in backend/models/
(ignored by Git), or in the folder given with --dest. Licence: InsightFace pretrained
models are for non-commercial research only.

Usage (from the backend folder):
  python scripts/download_face_model.py
  python scripts/download_face_model.py --from-zip ~/Downloads/buffalo_l.zip   # already downloaded
"""
import argparse
import hashlib
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

URL = "https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip"
MEMBER = "w600k_r50.onnx"
# SHA-256 of w600k_r50.onnx as used in the 9 Nov 2026 evaluation; None = print only.
EXPECTED_SHA256 = None


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dest", default=str(Path(__file__).resolve().parents[1] / "models"))
    ap.add_argument("--from-zip", help="use an already downloaded buffalo_l.zip")
    args = ap.parse_args()
    dest = Path(args.dest).expanduser()
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / MEMBER
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(args.from_zip).expanduser() if args.from_zip else Path(tmp) / "buffalo_l.zip"
        if not args.from_zip:
            print(f"Downloading {URL} (about 275 MB)...", flush=True)
            with urllib.request.urlopen(URL) as response, open(archive, "wb") as out:
                shutil.copyfileobj(response, out, 1 << 20)
        with zipfile.ZipFile(archive) as z:
            names = [n for n in z.namelist() if n.endswith(MEMBER)]
            if not names:
                sys.exit(f"{MEMBER} not found in {archive}")
            with z.open(names[0]) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out, 1 << 20)
    digest = sha256(target)
    print(f"Saved {target} ({target.stat().st_size / 1e6:.0f} MB), sha256 {digest}")
    if EXPECTED_SHA256 and digest != EXPECTED_SHA256:
        target.unlink()
        sys.exit("Checksum mismatch: the file was deleted. Download it again.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
