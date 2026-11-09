"""AI face matching for found-person identification (PBI 15/16).

Configuration C7, selected after the PBI 13 evaluation and the Sprint 2 field tests
(branch ai-face-matching; decision record in the project docs):
- Recognition: InsightFace ArcFace ResNet-50 trained on WebFace600K ("buffalo_l" pack,
  file w600k_r50.onnx), run with onnxruntime. Pre-trained, not fine-tuned.
- Detection: MTCNN (the `mtcnn` package), largest face in the photo.
- Alignment: the 5 MTCNN landmarks mapped onto the standard ArcFace 112x112 template.
- Comparison: cosine similarity of L2-normalised 512-d embeddings.

Rules:
- Embeddings never leave the backend: they are not returned by any endpoint
  and never logged.
- Results are ranked candidates for human review, never automatic confirmation.
- If the model is not installed or fails to load, matching reports
  'unavailable' and the Volunteer uses manual review.
- Embeddings are stored under a model-specific field (EMBEDDING_FIELD), so embeddings
  from a previous model are never compared with this one. Re-embed existing
  registrations with scripts/backfill_face_embeddings.py after a model change.

When a candidate is shown (search()):
- The threshold depends on the registered person's age (AGE_RULES): young children's
  faces produce more look-alike scores, so their thresholds are higher.
- Ages 0-5 also have a "clear winner" rule: the top candidate is shown when its score is
  at least `floor` and it beats every other registered person by at least `gap`.
- Registered people with an open missing-person case are searched first: if one of them
  is shown, other people are shown only when they score higher than that open case.
Values come from the UTKFace false-match test and the same-day field tests
(9 Nov 2026) and target about 1-3% wrong-person results with 100 registered people.

Settings (environment variables):
  RADD_FACE_MATCHING      'on' enables matching; unset or 'off' disables it
  RADD_FACE_MODEL_PATH    path of w600k_r50.onnx (default: backend/models/w600k_r50.onnx;
                          download with scripts/download_face_model.py)
  RADD_MATCH_RULES        optional JSON list of [max_age, threshold, floor, gap]
                          (floor/gap null = no clear-winner rule) to override AGE_RULES
  RADD_MATCH_TOP_K        maximum number of candidates returned (5)
"""
import io
import json
import logging
import math
import os
import threading
from pathlib import Path

from PIL import Image, ImageOps

MODEL = "ArcFace-R50-WebFace600K"
MODEL_FILE = "w600k_r50.onnx"
DETECTOR = "mtcnn"
EMBEDDING_SIZE = 512
EMBEDDING_FIELD = "face_embedding_arcface_r50"
# Fields written by earlier models; removed whenever a new embedding is written.
LEGACY_EMBEDDING_FIELDS = ("face_embedding",)

# (max_age, threshold, clear-winner floor, clear-winner gap), checked in order.
AGE_RULES = (
    (2, 0.65, 0.45, 0.25),
    (5, 0.60, 0.45, 0.15),
    (17, 0.38, None, None),
    (59, 0.30, None, None),
    (200, 0.38, None, None),
)
# Age missing or invalid (should not happen: age is required at registration).
UNKNOWN_AGE_RULE = (0.38, None, None)

# Standard ArcFace 112x112 landmark template: left eye, right eye, nose, left/right mouth.
ARCFACE_TEMPLATE = ((38.2946, 51.6963), (73.5318, 51.5014), (56.0252, 71.7366),
                    (41.5493, 92.3655), (70.7299, 92.2041))
MAX_SIDE = 1600  # large phone photos are scaled down before detection (speed only)

log = logging.getLogger(__name__)


def top_k():
    return int(os.environ.get("RADD_MATCH_TOP_K", "5"))


def age_rules():
    raw = os.environ.get("RADD_MATCH_RULES")
    if not raw:
        return AGE_RULES
    return tuple((int(a), float(t), None if f is None else float(f), None if g is None else float(g))
                 for a, t, f, g in json.loads(raw))


def rule_for_age(age):
    """(threshold, floor, gap) for a registered person's age."""
    if isinstance(age, bool) or not isinstance(age, (int, float)) or not math.isfinite(age) or age < 0:
        return UNKNOWN_AGE_RULE
    for max_age, threshold, floor, gap in age_rules():
        if age <= max_age:
            return threshold, floor, gap
    return UNKNOWN_AGE_RULE


def model_path():
    default = Path(__file__).resolve().parents[1] / "models" / MODEL_FILE
    return Path(os.environ.get("RADD_FACE_MODEL_PATH", str(default))).expanduser()


class Unavailable(Exception):
    """The face-matching model cannot be used right now."""


class ArcFaceEngine:
    """Loads the model and detector once (first use) and serialises inference."""

    def __init__(self):
        self._lock = threading.Lock()
        self._session = None
        self._input = None
        self._detector = None

    def _load(self):
        if self._session is None:
            try:
                import onnxruntime as ort
                from mtcnn import MTCNN
                path = model_path()
                if not path.is_file():
                    raise FileNotFoundError("face model file missing")
                session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
                detector = MTCNN()
            except Exception as error:  # missing package or model file, TensorFlow, onnxruntime
                log.error("face model unavailable: %s", type(error).__name__)
                raise Unavailable() from None
            self._session, self._input, self._detector = session, session.get_inputs()[0].name, detector

    def _represent(self, aligned_rgb):
        import numpy as np
        x = ((aligned_rgb.astype(np.float32) - 127.5) / 127.5).transpose(2, 0, 1)[None]
        return normalize(self._session.run(None, {self._input: x})[0][0])

    def warm_up(self):
        """Preflight recognition inference and MTCNN detection separately.

        Synthetic images only; no private photo is used. A uniform image has no face,
        so the detector returning no faces is normal.
        """
        try:
            import numpy as np
            with self._lock:
                self._load()
                self._represent(np.full((112, 112, 3), 127, dtype=np.uint8))
                self._detector.detect_faces(np.full((160, 160, 3), 127, dtype=np.uint8))
        except Unavailable:
            raise
        except Exception as error:
            log.error("face warm-up failed: %s", type(error).__name__)
            raise Unavailable() from None

    def embed(self, image_bytes):
        """Return the unit-length embedding of the main face, or None if no face is detected."""
        try:
            import numpy as np
            import cv2
            with Image.open(io.BytesIO(image_bytes)) as image:
                image = ImageOps.exif_transpose(image).convert("RGB")
                scale = MAX_SIDE / max(image.size)
                if scale < 1:
                    image = image.resize((round(image.width * scale), round(image.height * scale)),
                                         Image.BILINEAR)
                rgb = np.ascontiguousarray(np.asarray(image))
            with self._lock:
                self._load()
                faces = [f for f in (self._detector.detect_faces(rgb) or []) if f.get("keypoints")]
                if not faces:
                    return None
                # Several faces: use the largest, i.e. the person the photograph is of.
                face = max(faces, key=lambda f: f["box"][2] * f["box"][3])
                matrix = similarity_transform(five_points(face["keypoints"]))
                aligned = cv2.warpAffine(rgb, matrix, (112, 112), borderValue=0.0)
                return self._represent(aligned)
        except Unavailable:
            raise
        except Exception as error:
            log.error("face embedding failed: %s", type(error).__name__)
            raise Unavailable() from None


def five_points(keypoints):
    """MTCNN keypoints in template order, by image position (robust to left/right naming)."""
    eyes = sorted([keypoints["left_eye"], keypoints["right_eye"]], key=lambda p: p[0])
    mouth = sorted([keypoints["mouth_left"], keypoints["mouth_right"]], key=lambda p: p[0])
    return [eyes[0], eyes[1], keypoints["nose"], mouth[0], mouth[1]]


def similarity_transform(points):
    """Least-squares similarity transform (Umeyama) of the landmarks onto the template."""
    import numpy as np
    src = np.asarray(points, dtype=np.float64)
    dst = np.asarray(ARCFACE_TEMPLATE, dtype=np.float64)
    mu_s, mu_d = src.mean(0), dst.mean(0)
    s0, d0 = src - mu_s, dst - mu_d
    cov = d0.T @ s0 / len(src)
    u, sig, vt = np.linalg.svd(cov)
    d = np.ones(2)
    if np.linalg.det(cov) < 0:
        d[-1] = -1
    rot = u @ np.diag(d) @ vt
    var = (s0 ** 2).sum() / len(src)
    if var == 0:
        raise ValueError("degenerate landmarks")
    scale = (sig * d).sum() / var
    matrix = np.zeros((2, 3))
    matrix[:, :2] = scale * rot
    matrix[:, 2] = mu_d - scale * rot @ mu_s
    return matrix


_engine = None
_engine_lock = threading.Lock()


def get_engine():
    """The shared lazy engine, or None unless matching is explicitly enabled.

    Missing AI dependencies fail with Unavailable on embed(), never as disabled.
    """
    global _engine
    if os.environ.get("RADD_FACE_MATCHING", "off").lower() != "on":
        return None
    with _engine_lock:
        if _engine is None:
            _engine = ArcFaceEngine()
        return _engine


def set_engine(engine):
    """Replace the engine (tests use a fake; None resets lazy construction)."""
    global _engine
    _engine = engine


def normalize(vector):
    v = [float(x) for x in vector]
    n = math.sqrt(sum(x * x for x in v))
    if len(v) != EMBEDDING_SIZE or not math.isfinite(n) or n == 0:
        raise Unavailable()
    return [x / n for x in v]


def valid_embedding(value):
    return (isinstance(value, list) and len(value) == EMBEDDING_SIZE
            and all(isinstance(x, (int, float)) and math.isfinite(x) for x in value))


def similarity(a, b):
    """Cosine similarity of two unit-length embeddings (-1..1)."""
    return float(sum(x * y for x, y in zip(a, b)))


def display_score(value):
    """Similarity shown to the Volunteer, clipped to 0..1. Not a probability."""
    return round(min(1.0, max(0.0, value)), 4)


def match(probe, gallery, min_similarity, limit=None):
    """Rank gallery items by similarity to the probe with one fixed threshold.

    gallery: iterable of (item, embedding). Returns up to `limit` (item, similarity)
    pairs with similarity >= `min_similarity`, best first. Kept for evaluation scripts;
    the app uses search().
    """
    limit = top_k() if limit is None else limit
    scored = [(item, similarity(probe, emb)) for item, emb in gallery if valid_embedding(emb)]
    scored.sort(key=lambda pair: pair[1], reverse=True)
    return [(item, s) for item, s in scored if s >= min_similarity][:limit]


def search(probe, gallery, limit=None):
    """Candidates to show for a found person's embedding.

    gallery: iterable of (item, embedding, age, open_case). Returns up to `limit`
    (item, similarity) pairs, best first, following the age rules, the clear-winner
    rule and the open-cases-first rule described in the module docstring.
    """
    limit = top_k() if limit is None else limit
    scored = [(item, similarity(probe, emb), age, bool(open_case))
              for item, emb, age, open_case in gallery if valid_embedding(emb)]
    scored.sort(key=lambda entry: entry[1], reverse=True)

    def passes(index):
        _, score, age, _ = scored[index]
        threshold, floor, gap = rule_for_age(age)
        if score >= threshold:
            return True
        if floor is None or score < floor:
            return False
        # Clear winner: compared with EVERY other registered person, not only one stage.
        best_other = max((s for i, (_, s, _, _) in enumerate(scored) if i != index), default=-1.0)
        return score - best_other >= gap

    shown = [i for i, entry in enumerate(scored) if passes(i)]
    open_shown = [i for i in shown if scored[i][3]]
    if open_shown:
        # Open cases first: other people are shown only if they score higher than the best
        # open case, so a better match is never hidden behind a weaker open case.
        best_open = scored[open_shown[0]][1]
        shown = [i for i in shown if scored[i][3] or scored[i][1] > best_open]
    return [(scored[i][0], scored[i][1]) for i in shown][:limit]
