"""Face-matching settings: the ONE place to edit when the model or the matching rules change.

How to change something later:
- Thresholds or the clear-winner rule: edit AGE_RULES below (or set RADD_MATCH_RULES
  in the environment for a quick test, no code change). No re-embedding is needed.
- The model: add an engine class to app/face_engines.py, register it in ENGINES there,
  set ENGINE below, add the old EMBEDDING_FIELD to OLD_EMBEDDING_FIELDS, re-calibrate
  AGE_RULES (scores of different models are on different scales), then re-embed existing
  registrations with scripts/backfill_face_embeddings.py.
"""

# Which engine in app/face_engines.ENGINES is used.
ENGINE = "arcface_r50"

# Embeddings are stored under a field named after the engine, so embeddings made by a
# different model are never compared with the current one.
EMBEDDING_FIELD = "face_embedding_" + ENGINE

# Fields written by earlier engines. They are deleted whenever a new embedding is written
# (registration photo saved, or the backfill script).
OLD_EMBEDDING_FIELDS = ("face_embedding",)  # Facenet512 (DeepFace), until Nov 2026

# The ArcFace R50 model file and where scripts/download_face_model.py gets it.
MODEL_FILE = "w600k_r50.onnx"
MODEL_URL = "https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip"
MODEL_SHA256 = None  # set after the first verified download; None = print only

# When a candidate is shown, by the registered person's age:
#   (max_age, threshold, clear_winner_floor, clear_winner_gap), checked in order.
# A candidate is shown if its similarity >= threshold, or (ages 0-5) if it is >= floor
# AND ahead of every other registered person by >= gap.
# Source: UTKFace false-match test and same-day field tests, 9 Nov 2026 (project docs).
AGE_RULES = (
    (2, 0.65, 0.45, 0.25),
    (5, 0.60, 0.45, 0.15),
    (17, 0.38, None, None),
    (59, 0.30, None, None),
    (200, 0.38, None, None),
)
# Age missing or invalid (should not happen: age is required at registration).
UNKNOWN_AGE_RULE = (0.38, None, None)

# Maximum number of candidates returned to the Volunteer.
TOP_K = 5
