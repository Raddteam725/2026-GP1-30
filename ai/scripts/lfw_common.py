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
DETECTORS = ["yunet", "mtcnn"]
NORMALIZATIONS = ["base", "raw", "Facenet", "Facenet2018", "ArcFace", "VGGFace", "VGGFace2"]
DEFAULT_DETECTOR, DEFAULT_NORMALIZATION = "yunet", "base"

# Simulated field-photo conditions (applied to the second photo of a pair only,
# like a volunteer's phone photo compared with a registered photo).
CONDITIONS = ["blur", "low_resolution", "dark", "jpeg"]


def config_tag(model, detector=DEFAULT_DETECTOR, normalization=DEFAULT_NORMALIZATION):
    """Name used for caches and result folders. The default setup keeps the plain
    model name, so the first runs' cached embeddings are reused."""
    if detector == DEFAULT_DETECTOR and normalization == DEFAULT_NORMALIZATION:
        return model
    return f"{model}_{detector}_{normalization}"


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


def degrade(path, condition):
    """Load an image and apply one simulated field-photo condition (BGR uint8)."""
    import cv2
    img = cv2.imread(str(path))
    if condition == "blur":                 # out-of-focus / motion
        return cv2.GaussianBlur(img, (0, 0), 2.5)
    if condition == "low_resolution":       # person far away: ~40 px face
        h, w = img.shape[:2]
        small = cv2.resize(img, (w // 6, h // 6), interpolation=cv2.INTER_AREA)
        return cv2.resize(small, (w, h), interpolation=cv2.INTER_LINEAR)
    if condition == "dark":                 # poor lighting
        return np.clip(img.astype(np.float32) * 0.35, 0, 255).astype(np.uint8)
    if condition == "jpeg":                 # heavy compression
        ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 15])
        return cv2.imdecode(buf, cv2.IMREAD_COLOR)
    raise ValueError(condition)


def embed_one(source, model, detector, normalization):
    """source: image path or BGR array. Returns (L2-normalised embedding, face_found).
    If the detector finds no face, fall back to the whole image (LFW images are
    already centred on the face)."""
    from deepface import DeepFace
    src = str(source) if not isinstance(source, np.ndarray) else source
    try:
        rep = DeepFace.represent(img_path=src, model_name=model, detector_backend=detector,
                                 enforce_detection=True, align=True, normalization=normalization)
        found = True
    except ValueError:
        rep = DeepFace.represent(img_path=src, model_name=model, detector_backend="skip",
                                 enforce_detection=False, align=True, normalization=normalization)
        found = False
    if len(rep) > 1:   # several faces: LFW's labelled person is the one in the centre (250x250 images)
        def off_centre(r):
            a = r["facial_area"]
            return (a.get("x", 0) + a["w"] / 2 - 125) ** 2 + (a.get("y", 0) + a["h"] / 2 - 125) ** 2
        rep = sorted(rep, key=off_centre)
    v = np.asarray(rep[0]["embedding"], dtype=np.float32)
    return v / (np.linalg.norm(v) + 1e-12), found


def embed_all(items, model, cache_name, detector=DEFAULT_DETECTOR, normalization=DEFAULT_NORMALIZATION):
    """items: list of keys. A key is an image path, or 'path|condition' for a
    degraded copy. Embeds each key once, with a cache so an interrupted run resumes."""
    EMB_DIR.mkdir(exist_ok=True)
    cache = EMB_DIR / f"{cache_name}.npz"
    done = {}
    if cache.exists():
        z = np.load(cache, allow_pickle=False)
        done = {p: (e, bool(f)) for p, e, f in zip(z["paths"], z["emb"], z["found"])}
    keys = [str(k) for k in items]
    todo = [k for k in dict.fromkeys(keys) if k not in done]
    print(f"{cache_name}: {len(keys) - len([k for k in keys if k in todo])} cached, {len(todo)} to embed", flush=True)
    t0 = time.perf_counter()
    for i, k in enumerate(todo, 1):
        path, _, cond = k.partition("|")
        done[k] = embed_one(degrade(path, cond) if cond else path, model, detector, normalization)
        if i % 250 == 0 or i == len(todo):
            el = time.perf_counter() - t0
            print(f"  {i}/{len(todo)} images | {el/60:.1f} min elapsed | ~{el/i*(len(todo)-i)/60:.1f} min left", flush=True)
            ks = list(done)
            np.savez(cache, paths=np.array(ks), emb=np.stack([done[x][0] for x in ks]),
                     found=np.array([done[x][1] for x in ks]))
    return {k: done[k][0] for k in keys}, {k: done[k][1] for k in keys}
