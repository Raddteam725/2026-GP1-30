"""AI face matching for found-person identification (PBI 15/16).

Uses the configuration selected by the PBI 13 evaluation (ai/ folder, branch
ai-face-matching): Facenet512 with model-specific normalisation (Facenet2018)
and the MTCNN face detector, comparing L2-normalised embeddings with cosine
similarity.

Rules:
- Embeddings never leave the backend: they are not returned by any endpoint
  and never logged.
- Results are ranked candidates for human review, never automatic confirmation.
- If the model is not installed or fails to load, matching reports
  'unavailable' and the Volunteer uses manual review.

Settings (environment variables, defaults from the evaluation):
  RADD_FACE_MATCHING      'off' disables matching entirely
  RADD_MATCH_THRESHOLD    minimum similarity for a reliable candidate (0.596:
                          ~5% false alarms for 100 registered people on LFW)
  RADD_MATCH_TOP_K        maximum number of candidates returned (5)
"""
import importlib.util
import io
import logging
import math
import os
import threading

import numpy as np
from PIL import Image, ImageOps

MODEL = "Facenet512"
DETECTOR = "mtcnn"
NORMALIZATION = "Facenet2018"
EMBEDDING_SIZE = 512
EMBEDDING_FIELD = "face_embedding"

log = logging.getLogger(__name__)


def threshold():
    return float(os.environ.get("RADD_MATCH_THRESHOLD", "0.596"))


def top_k():
    return int(os.environ.get("RADD_MATCH_TOP_K", "5"))


class Unavailable(Exception):
    """The face-matching model cannot be used right now."""


class DeepFaceEngine:
    """Loads the model once (first use) and serialises inference."""

    def __init__(self):
        self._lock = threading.Lock()
        self._deepface = None

    def _load(self):
        if self._deepface is None:
            try:
                from deepface import DeepFace
                DeepFace.build_model(MODEL)
            except Exception as error:  # missing package, weights download, TensorFlow
                log.error("face model unavailable: %s", type(error).__name__)
                raise Unavailable() from None
            self._deepface = DeepFace

    def warm_up(self):
        with self._lock:
            self._load()

    def embed(self, image_bytes):
        """Return the unit-length embedding of the main face, or None if no face is detected."""
        with Image.open(io.BytesIO(image_bytes)) as image:
            rgb = np.asarray(ImageOps.exif_transpose(image).convert("RGB"))
        bgr = np.ascontiguousarray(rgb[:, :, ::-1])
        with self._lock:
            self._load()
            try:
                faces = self._deepface.represent(
                    img_path=bgr, model_name=MODEL, detector_backend=DETECTOR,
                    enforce_detection=True, align=True, normalization=NORMALIZATION)
            except ValueError:
                return None  # DeepFace raises ValueError when no face is detected
            except Exception as error:
                log.error("face embedding failed: %s", type(error).__name__)
                raise Unavailable() from None
        if not faces:
            return None
        # Several faces: use the largest, i.e. the person the photograph is of.
        face = max(faces, key=lambda f: f["facial_area"]["w"] * f["facial_area"]["h"])
        return normalize(face["embedding"])


_engine = None
_engine_lock = threading.Lock()


def get_engine():
    """The shared engine, or None when matching is disabled or not installed."""
    global _engine
    if os.environ.get("RADD_FACE_MATCHING", "on").lower() == "off":
        return None
    with _engine_lock:
        if _engine is None:
            if importlib.util.find_spec("deepface") is None:
                return None
            _engine = DeepFaceEngine()
        return _engine


def set_engine(engine):
    """Replace the engine (tests use a fake; None disables matching)."""
    global _engine
    _engine = engine


def normalize(vector):
    v = np.asarray(vector, dtype=np.float64)
    n = float(np.linalg.norm(v))
    if v.shape != (EMBEDDING_SIZE,) or not math.isfinite(n) or n == 0:
        raise Unavailable()
    return (v / n).tolist()


def valid_embedding(value):
    return (isinstance(value, list) and len(value) == EMBEDDING_SIZE
            and all(isinstance(x, (int, float)) and math.isfinite(x) for x in value))


def similarity(a, b):
    """Cosine similarity of two unit-length embeddings (-1..1)."""
    return float(np.dot(np.asarray(a, dtype=np.float64), np.asarray(b, dtype=np.float64)))


def display_score(value):
    """Similarity shown to the Volunteer, clipped to 0..1. Not a probability."""
    return round(min(1.0, max(0.0, value)), 4)


def match(probe, gallery, min_similarity=None, limit=None):
    """Rank gallery items by similarity to the probe.

    gallery: iterable of (item, embedding). Returns up to `limit` (item, similarity)
    pairs with similarity >= `min_similarity`, best first. An empty list means
    no reliable candidate.
    """
    min_similarity = threshold() if min_similarity is None else min_similarity
    limit = top_k() if limit is None else limit
    scored = [(item, similarity(probe, emb)) for item, emb in gallery if valid_embedding(emb)]
    scored.sort(key=lambda pair: pair[1], reverse=True)
    return [(item, s) for item, s in scored if s >= min_similarity][:limit]
