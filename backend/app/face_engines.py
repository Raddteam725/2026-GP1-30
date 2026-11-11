"""Face-recognition engines for app/face_matching.py.

An engine turns a photograph into one face embedding. Every engine has the same interface:
  warm_up()           check the model and detector with synthetic images (startup)
  embed(image_bytes)  unit-length list of EMBEDDING_SIZE floats, or None if no face is found;
                      raises Unavailable if the model cannot be used
Nothing else in the backend depends on which model is used.

To add a model: write a class with that interface below, register it in ENGINES, and follow
the steps in app/face_config.py. Heavy packages (numpy, onnxruntime, mtcnn, cv2) are imported
only inside methods, so the backend still runs without the AI packages installed.

Current engine "arcface_r50" (configuration C7):
- Recognition: InsightFace ArcFace ResNet-50 trained on WebFace600K (w600k_r50.onnx), via
  onnxruntime. Pre-trained, not fine-tuned. Licence: non-commercial research only.
- Detection: MTCNN, largest face in the photo.
- Alignment: 5 MTCNN landmarks mapped onto the standard ArcFace 112x112 template.
"""
import io
import logging
import math
import os
import threading
from pathlib import Path

from PIL import Image, ImageOps

from . import face_config

EMBEDDING_SIZE = 512

# Standard ArcFace 112x112 landmark template: left eye, right eye, nose, left/right mouth.
ARCFACE_TEMPLATE = ((38.2946, 51.6963), (73.5318, 51.5014), (56.0252, 71.7366),
                    (41.5493, 92.3655), (70.7299, 92.2041))
MAX_SIDE = 1600  # large phone photos are scaled down before detection (speed only)

log = logging.getLogger(__name__)


def model_path():
    default = Path(__file__).resolve().parents[1] / "models" / face_config.MODEL_FILE
    return Path(os.environ.get("RADD_FACE_MODEL_PATH", str(default))).expanduser()


class Unavailable(Exception):
    """The face-matching model cannot be used right now."""


class ArcFaceOnnxEngine:
    """InsightFace ArcFace (ONNX) + MTCNN. Loads once (first use) and serialises inference."""

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


def normalize(vector):
    v = [float(x) for x in vector]
    n = math.sqrt(sum(x * x for x in v))
    if len(v) != EMBEDDING_SIZE or not math.isfinite(n) or n == 0:
        raise Unavailable()
    return [x / n for x in v]


# Engine registry: face_config.ENGINE selects one of these.
ENGINES = {
    "arcface_r50": ArcFaceOnnxEngine,
}
