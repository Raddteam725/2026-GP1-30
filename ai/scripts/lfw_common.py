"""Shared helpers for the Radd face-matching evaluation (PBI 13).

Loads the LFW protocols from the Kaggle copy (jessicali9530) in ai/data/lfw and
computes face embeddings through DeepFace. Only numbers are ever written to
ai/results; embeddings are cached in ai/embeddings, which Git ignores.
"""
from pathlib import Path
import time

import numpy as np
import pandas as pd

AI_DIR = Path(__file__).resolve().parents[1]
DATA = AI_DIR / "data" / "lfw"
IMG = DATA / "lfw-deepfunneled" / "lfw-deepfunneled"
EMB_DIR = AI_DIR / "embeddings"
RESULTS = AI_DIR / "results"

MODELS = ["ArcFace", "Facenet512", "SFace"]
DETECTOR = "yunet"   # chosen from the detector test: 30/30 faces, 0.01 s per image


def img_path(name, num):
    return IMG / str(name) / f"{name}_{int(num):04d}.jpg"


def load_view1(split):
    """View 1 (development). split = 'DevTrain' or 'DevTest'."""
    match = pd.read_csv(DATA / f"matchpairs{split}.csv")
    mismatch = pd.read_csv(DATA / f"mismatchpairs{split}.csv")
    rows = [(img_path(r.name, r.imagenum1), img_path(r.name, r.imagenum2), 1) for r in match.itertuples()]
    rows += [(img_path(r.name, r.imagenum1), img_path(r._3, r.imagenum2), 0) for r in mismatch.itertuples()]
    return pd.DataFrame(rows, columns=["img1", "img2", "same"])


def load_view2():
    """View 2 (final test): 10 folds of 300 same + 300 different pairs, in file order."""
    df = pd.read_csv(DATA / "pairs.csv")
    rows = []
    for i, r in enumerate(df.itertuples()):
        fold = i // 600
        if pd.isna(r._4):
            rows.append((img_path(r.name, r.imagenum1), img_path(r.name, r.imagenum2), 1, fold))
        else:
            rows.append((img_path(r.name, r.imagenum1), img_path(r.imagenum2, r._4), 0, fold))
    return pd.DataFrame(rows, columns=["img1", "img2", "same", "fold"])


def check_images(*frames):
    missing = [p for df in frames for p in pd.concat([df.img1, df.img2]) if not Path(p).exists()]
    if missing:
        raise FileNotFoundError(f"{len(missing)} images missing, first: {missing[0]}")


def embed_one(path, model):
    """Return (L2-normalised embedding, face_found). If the detector finds no face,
    fall back to the whole image (LFW images are already centred on the face)."""
    from deepface import DeepFace
    try:
        rep = DeepFace.represent(img_path=str(path), model_name=model, detector_backend=DETECTOR,
                                 enforce_detection=True, align=True)
        found = True
    except ValueError:
        rep = DeepFace.represent(img_path=str(path), model_name=model, detector_backend="skip",
                                 enforce_detection=False, align=True)
        found = False
    if len(rep) > 1:   # several faces: LFW's labelled person is the one in the centre (250x250 images)
        def off_centre(r):
            a = r["facial_area"]
            return (a.get("x", 0) + a["w"] / 2 - 125) ** 2 + (a.get("y", 0) + a["h"] / 2 - 125) ** 2
        rep = sorted(rep, key=off_centre)
    v = np.asarray(rep[0]["embedding"], dtype=np.float32)
    return v / (np.linalg.norm(v) + 1e-12), found


def embed_all(paths, model, cache_name):
    """Embed every path once, with a cache so an interrupted run can resume."""
    EMB_DIR.mkdir(exist_ok=True)
    cache = EMB_DIR / f"{cache_name}.npz"
    done = {}
    if cache.exists():
        z = np.load(cache, allow_pickle=False)
        done = {p: (e, bool(f)) for p, e, f in zip(z["paths"], z["emb"], z["found"])}
    todo = [str(p) for p in paths if str(p) not in done]
    print(f"{model}: {len(done)} cached, {len(todo)} to embed")
    t0 = time.perf_counter()
    for i, p in enumerate(todo, 1):
        done[p] = embed_one(p, model)
        if i % 250 == 0 or i == len(todo):
            el = time.perf_counter() - t0
            print(f"  {i}/{len(todo)} images | {el/60:.1f} min elapsed | ~{el/i*(len(todo)-i)/60:.1f} min left", flush=True)
            keys = list(done)
            np.savez(cache, paths=np.array(keys), emb=np.stack([done[k][0] for k in keys]),
                     found=np.array([done[k][1] for k in keys]))
    return {p: done[str(p)][0] for p in paths}, {p: done[str(p)][1] for p in paths}
