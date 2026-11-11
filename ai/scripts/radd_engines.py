"""Face-recognition engines for Radd's offline field tests (PBI 13 follow-up).

Self-contained: nothing is imported from the backend, so these scripts keep working
whatever the app's code looks like.

  facenet512  C6, the original app engine: DeepFace Facenet512 + MTCNN, Facenet2018
              normalisation, largest face (same settings as the October evaluation)
  arcface     C7, the engine the app now uses: InsightFace ArcFace ResNet-50 trained on
              WebFace600K ("buffalo_l" pack, file w600k_r50.onnx), run with onnxruntime.
  arcface100  InsightFace ArcFace ResNet-100 trained on Glint360K ("antelopev2" pack,
              file glintr100.onnx); same pipeline, larger model. Faces are found with the same
              MTCNN detector and aligned with the standard 5-point ArcFace template.
              No InsightFace package and no C++ build tools are needed.

All engines have the same interface: warm_up(), and
embed(image_bytes) -> unit-length list of floats, or None if no face is found.

Licence note: the InsightFace pretrained models are for non-commercial research only
(the same situation as the ArcFace weights noted in the PBI 13 evaluation).
"""
import io
import math
import threading
from pathlib import Path

EMBEDDING_SIZE = 512
FACENET_MODEL, FACENET_DETECTOR, FACENET_NORMALIZATION = 'Facenet512', 'mtcnn', 'Facenet2018'


class Unavailable(Exception):
    """The model could not produce a valid embedding."""


# Standard ArcFace 112x112 landmark template: left eye, right eye, nose, left mouth, right mouth.
ARCFACE_TEMPLATE = [[38.2946, 51.6963], [73.5318, 51.5014], [56.0252, 71.7366],
                    [41.5493, 92.3655], [70.7299, 92.2041]]
MAX_SIDE = 1600  # large phone photos are scaled down before detection (speed only)


def unit(vector):
    v = [float(x) for x in vector]
    n = math.sqrt(sum(x * x for x in v))
    if not math.isfinite(n) or n == 0:
        raise Unavailable()
    return [x / n for x in v]


def decode_rgb(image_bytes, max_side=MAX_SIDE):
    import numpy as np
    from PIL import Image, ImageOps
    with Image.open(io.BytesIO(image_bytes)) as image:
        image = ImageOps.exif_transpose(image).convert('RGB')
        scale = max_side / max(image.size) if max_side else 1
        if scale < 1:
            image = image.resize((round(image.width * scale), round(image.height * scale)), Image.BILINEAR)
        return np.asarray(image)


def five_points(keypoints):
    """Order MTCNN keypoints as the template expects, by image position (robust to
    left/right naming conventions)."""
    eyes = sorted([keypoints['left_eye'], keypoints['right_eye']], key=lambda p: p[0])
    mouth = sorted([keypoints['mouth_left'], keypoints['mouth_right']], key=lambda p: p[0])
    return [eyes[0], eyes[1], keypoints['nose'], mouth[0], mouth[1]]


def similarity_transform(src, dst):
    """Least-squares similarity transform (Umeyama 1991), as used by InsightFace's alignment."""
    import numpy as np
    src, dst = np.asarray(src, dtype=np.float64), np.asarray(dst, dtype=np.float64)
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
        return None
    scale = (sig * d).sum() / var
    matrix = np.zeros((2, 3))
    matrix[:, :2] = scale * rot
    matrix[:, 2] = mu_d - scale * rot @ mu_s
    return matrix


def align(rgb, points):
    """Warp the face onto the 112x112 ArcFace template."""
    import cv2
    matrix = similarity_transform(points, ARCFACE_TEMPLATE)
    if matrix is None:
        return None
    return cv2.warpAffine(rgb, matrix, (112, 112), borderValue=0.0)


class ArcFaceOnnxEngine:
    def __init__(self, model_path, name='arcface'):
        self.name = name
        self.model_path = Path(model_path).expanduser()
        self._lock = threading.Lock()
        self._session = None
        self._detector = None

    def _load(self):
        if self._session is None:
            if not self.model_path.is_file():
                raise SystemExit(f'ArcFace model not found: {self.model_path} (see the setup steps)')
            import onnxruntime as ort
            from mtcnn import MTCNN
            self._session = ort.InferenceSession(str(self.model_path), providers=['CPUExecutionProvider'])
            self._input = self._session.get_inputs()[0].name
            self._detector = MTCNN()

    def _represent(self, aligned_rgb):
        import numpy as np
        x = (aligned_rgb.astype(np.float32) - 127.5) / 127.5      # w600k_r50: mean 127.5, std 127.5, RGB
        x = np.transpose(x, (2, 0, 1))[None, ...]
        return unit(self._session.run(None, {self._input: x})[0][0])

    def warm_up(self):
        import numpy as np
        with self._lock:
            self._load()
            vector = self._represent(np.full((112, 112, 3), 127, dtype=np.uint8))
            if len(vector) != EMBEDDING_SIZE:
                raise SystemExit(f'Unexpected ArcFace output size {len(vector)} (expected {EMBEDDING_SIZE})')
            self._detector.detect_faces(np.full((160, 160, 3), 127, dtype=np.uint8))

    def embed(self, image_bytes):
        rgb = decode_rgb(image_bytes)
        with self._lock:
            self._load()
            faces = [f for f in (self._detector.detect_faces(rgb) or []) if f.get('keypoints')]
            if not faces:
                return None
            face = max(faces, key=lambda f: f['box'][2] * f['box'][3])  # largest face, as in the app
            aligned = align(rgb, five_points(face['keypoints']))
            if aligned is None:
                return None
            return self._represent(aligned)


def similarity(a, b):
    """Cosine similarity of two unit-length embeddings."""
    return sum(x * y for x, y in zip(a, b))


class Facenet512Engine:
    """C6: DeepFace Facenet512 with the MTCNN detector."""

    def __init__(self):
        self.name = 'facenet512'
        self._lock = threading.Lock()
        self._deepface = None

    def _load(self):
        if self._deepface is None:
            from deepface import DeepFace
            from deepface.modules.exceptions import FaceNotDetected
            DeepFace.build_model(FACENET_MODEL)
            self._deepface, self._no_face = DeepFace, FaceNotDetected

    def warm_up(self):
        import numpy as np
        with self._lock:
            self._load()
            out = self._deepface.represent(img_path=np.full((160, 160, 3), 127, dtype=np.uint8),
                                           model_name=FACENET_MODEL, detector_backend='skip',
                                           enforce_detection=False, align=False,
                                           normalization=FACENET_NORMALIZATION)
            if len(out[0]['embedding']) != EMBEDDING_SIZE:
                raise SystemExit('Unexpected Facenet512 output size')

    def embed(self, image_bytes):
        import numpy as np
        rgb = decode_rgb(image_bytes, max_side=None)  # full size, as the original app engine
        bgr = np.ascontiguousarray(rgb[:, :, ::-1])  # DeepFace expects OpenCV (BGR) order
        with self._lock:
            self._load()
            try:
                faces = self._deepface.represent(img_path=bgr, model_name=FACENET_MODEL,
                                                 detector_backend=FACENET_DETECTOR, enforce_detection=True,
                                                 align=True, normalization=FACENET_NORMALIZATION)
            except self._no_face:
                return None
        if not faces:
            return None
        face = max(faces, key=lambda f: f['facial_area']['w'] * f['facial_area']['h'])
        return unit(face['embedding'])


def make_engine(name, arcface_model=None):
    if name == 'facenet512':
        return Facenet512Engine()
    if name == 'arcface':
        return ArcFaceOnnxEngine(arcface_model or Path.home() / 'RaddModels' / 'w600k_r50.onnx', 'arcface')
    if name == 'arcface100':
        return ArcFaceOnnxEngine(Path.home() / 'RaddModels' / 'glintr100.onnx', 'arcface100')
    raise SystemExit(f'Unknown engine {name!r} (use facenet512, arcface or arcface100)')
