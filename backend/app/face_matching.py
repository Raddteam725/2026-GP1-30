"""AI face matching for found-person identification (PBI 15/16).

Files:
- app/face_config.py   settings that change with the model or the matching rules (edit here)
- app/face_engines.py  the face-recognition model(s): photo -> embedding
- app/face_matching.py (this file) which registered people are shown as candidates

Rules:
- Embeddings never leave the backend: they are not returned by any endpoint
  and never logged.
- Results are ranked candidates for human review, never automatic confirmation.
- If the model is not installed or fails to load, matching reports
  'unavailable' and the Volunteer uses manual review.
- Embeddings are stored under a model-specific field (EMBEDDING_FIELD), so embeddings
  from a previous model are never compared with the current one.

When a candidate is shown (search()):
- The threshold depends on the registered person's age (face_config.AGE_RULES).
- Ages 0-5 also have a "clear winner" rule: the top candidate is shown when its score is
  at least `floor` and it beats every other registered person by at least `gap`.
- Registered people with an open missing-person case are searched first: if one of them
  is shown, other people are shown only when they score higher than that open case.

Settings (environment variables):
  RADD_FACE_MATCHING      'on' enables matching; unset or 'off' disables it
  RADD_FACE_MODEL_PATH    model file path (default: backend/models/<face_config.MODEL_FILE>)
  RADD_MATCH_RULES        optional JSON list of [max_age, threshold, floor, gap] that
                          overrides face_config.AGE_RULES (for tests and tuning)
  RADD_MATCH_TOP_K        maximum number of candidates returned (face_config.TOP_K)
"""
import json
import math
import os
import threading

from . import face_config
from .face_engines import (EMBEDDING_SIZE, ENGINES, Unavailable, normalize,  # noqa: F401 (re-exported)
                           ArcFaceOnnxEngine as ArcFaceEngine, ARCFACE_TEMPLATE, similarity_transform)

ENGINE = face_config.ENGINE
EMBEDDING_FIELD = face_config.EMBEDDING_FIELD
LEGACY_EMBEDDING_FIELDS = tuple(f for f in face_config.OLD_EMBEDDING_FIELDS if f != EMBEDDING_FIELD)


def top_k():
    return int(os.environ.get("RADD_MATCH_TOP_K", str(face_config.TOP_K)))


def age_rules():
    raw = os.environ.get("RADD_MATCH_RULES")
    if not raw:
        return face_config.AGE_RULES
    return tuple((int(a), float(t), None if f is None else float(f), None if g is None else float(g))
                 for a, t, f, g in json.loads(raw))


def rule_for_age(age):
    """(threshold, floor, gap) for a registered person's age."""
    if isinstance(age, bool) or not isinstance(age, (int, float)) or not math.isfinite(age) or age < 0:
        return face_config.UNKNOWN_AGE_RULE
    for max_age, threshold, floor, gap in age_rules():
        if age <= max_age:
            return threshold, floor, gap
    return face_config.UNKNOWN_AGE_RULE


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
            _engine = ENGINES[ENGINE]()
        return _engine


def set_engine(engine):
    """Replace the engine (tests use a fake; None resets lazy construction)."""
    global _engine
    _engine = engine


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
