"""InsightFace ArcFace models (ONNX) for the PBI 13 evaluation, configuration C7 and later.

Not DeepFace's "ArcFace" (a Keras ResNet-34 port). These are InsightFace's own released
recognition models, run with onnxruntime:
  ArcFaceR50   buffalo_l pack,  w600k_r50.onnx  (ResNet-50, trained on WebFace600K)
  ArcFaceR100  antelopev2 pack, glintr100.onnx  (ResNet-100, trained on Glint360K)

Pipeline, kept as close as possible to the DeepFace configurations:
- Detection: the same MTCNN detector package DeepFace uses (RGB input).
- Several faces: the face closest to the image centre (for LFW's 250x250 images this is the
  same (125, 125) rule as lfw_common.embed_one; for other image sizes it uses their real centre).
- Alignment: 5 MTCNN landmarks -> least-squares similarity transform onto the standard
  ArcFace 112x112 template (the alignment these models were trained with).
- No face detected: the whole image, letterboxed to 112x112 (the benchmark fallback, like
  DeepFace's detector_backend="skip").
- Input: RGB, (pixel - 127.5) / 127.5, NCHW. Output: 512-d, L2-normalised by the caller.

Model files are looked up in ai/models/ (ignored by Git), then ~/RaddModels/.
Licence: InsightFace pretrained models are for non-commercial research only.
"""
from pathlib import Path

import numpy as np

AI_DIR = Path(__file__).resolve().parents[1]
MODEL_FILES = {"ArcFaceR50": "w600k_r50.onnx", "ArcFaceR100": "glintr100.onnx"}
TEMPLATE = np.array([[38.2946, 51.6963], [73.5318, 51.5014], [56.0252, 71.7366],
                     [41.5493, 92.3655], [70.7299, 92.2041]], dtype=np.float64)

_sessions, _detector = {}, None


def model_path(model):
    name = MODEL_FILES[model]
    for folder in (AI_DIR / "models", Path.home() / "RaddModels"):
        if (folder / name).is_file():
            return folder / name
    raise FileNotFoundError(f"{name} not found in ai/models/ or ~/RaddModels/")


def session(model):
    if model not in _sessions:
        import onnxruntime as ort
        _sessions[model] = ort.InferenceSession(str(model_path(model)), providers=["CPUExecutionProvider"])
    return _sessions[model]


def detector():
    global _detector
    if _detector is None:
        from mtcnn import MTCNN
        _detector = MTCNN()
    return _detector


def similarity_transform(src, dst=TEMPLATE):
    """Least-squares similarity transform (Umeyama), as in InsightFace's face_align."""
    src = np.asarray(src, dtype=np.float64)
    mu_s, mu_d = src.mean(0), dst.mean(0)
    s0, d0 = src - mu_s, dst - mu_d
    cov = d0.T @ s0 / len(src)
    u, sig, vt = np.linalg.svd(cov)
    d = np.ones(2)
    if np.linalg.det(cov) < 0:
        d[-1] = -1
    rot = u @ np.diag(d) @ vt
    var = (s0 ** 2).sum() / len(src)
    scale = (sig * d).sum() / var
    m = np.zeros((2, 3))
    m[:, :2] = scale * rot
    m[:, 2] = mu_d - scale * rot @ mu_s
    return m


def five_points(kp):
    eyes = sorted([kp["left_eye"], kp["right_eye"]], key=lambda p: p[0])
    mouth = sorted([kp["mouth_left"], kp["mouth_right"]], key=lambda p: p[0])
    return [eyes[0], eyes[1], kp["nose"], mouth[0], mouth[1]]


def letterbox(rgb, size=112):
    import cv2
    h, w = rgb.shape[:2]
    f = size / max(h, w)
    small = cv2.resize(rgb, (max(1, round(w * f)), max(1, round(h * f))))
    out = np.zeros((size, size, 3), dtype=np.uint8)
    y, x = (size - small.shape[0]) // 2, (size - small.shape[1]) // 2
    out[y:y + small.shape[0], x:x + small.shape[1]] = small
    return out


def read_bgr(source):
    import cv2
    if isinstance(source, np.ndarray):
        return source
    return cv2.imdecode(np.fromfile(str(source), dtype=np.uint8), cv2.IMREAD_COLOR)  # works for non-ASCII paths


def embed(source, model, detector_backend):
    """Returns (embedding as float32 array, face_found)."""
    import cv2
    if detector_backend != "mtcnn":
        raise ValueError(f"{model} is evaluated with --detector mtcnn only")
    rgb = np.ascontiguousarray(read_bgr(source)[:, :, ::-1])
    faces = [f for f in (detector().detect_faces(rgb) or []) if f.get("keypoints")]
    if faces:
        h, w = rgb.shape[:2]

        def off_centre(f):
            x, y, bw, bh = f["box"]
            return (x + bw / 2 - w / 2) ** 2 + (y + bh / 2 - h / 2) ** 2
        face = min(faces, key=off_centre)
        crop = cv2.warpAffine(rgb, similarity_transform(five_points(face["keypoints"])), (112, 112),
                              borderValue=0.0)
        found = True
    else:
        crop, found = letterbox(rgb), False
    x = ((crop.astype(np.float32) - 127.5) / 127.5).transpose(2, 0, 1)[None]
    sess = session(model)
    v = sess.run(None, {sess.get_inputs()[0].name: x})[0][0].astype(np.float32)
    return v, found
