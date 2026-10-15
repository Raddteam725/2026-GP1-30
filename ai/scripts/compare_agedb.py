"""Paired comparison of two configurations on the same AgeDB pairs (PBI 13).

Usage (from the ai folder, after evaluate_agedb.py has run for both configurations,
so the embeddings are cached and nothing is recomputed):
    python scripts/compare_agedb.py

Compares C6 (Facenet512 + MTCNN + Facenet2018) with C3 (ArcFace + YuNet + ArcFace)
on the identical AgeDB-30-style pairs from evaluate_agedb.py (seed 0). The
difference C6 - C3 gets an identity-level paired bootstrap 95% CI: the same
resampled people are used for both configurations. A CI that excludes 0 supports
a difference on these team-generated pairs; it is still not an official
AgeDB-30 benchmark result.

Two views: all_photos (no-face fallback), and face_detected_in_both_configs
(pairs where both configurations detected a face in both photos).

Writes results/agedb_comparison_C6_vs_C3.json (numbers only).
"""
import json
from datetime import datetime, timezone

import numpy as np
from sklearn.metrics import roc_auc_score

from evaluate_agedb import (RESULTS, IdentityBootstrap, build_pairs, load_photos, VERSION)
from lfw_common import config_tag, embed_all

CONFIGS = {"C6": ("Facenet512", "mtcnn", "Facenet2018"), "C3": ("ArcFace", "yunet", "ArcFace")}


def main():
    people, _, _ = load_photos()
    same, main_same, neg_matched, _ = build_pairs(people)
    pairs = main_same + neg_matched
    y = np.array([True] * len(main_same) + [False] * len(neg_matched))
    paths = sorted({str(x) for p in pairs for x in p[:2]})

    scores, detected, thresholds = {}, {}, {}
    for label, (model, det, norm) in CONFIGS.items():
        tag = config_tag(model, det, norm)
        emb, found = embed_all(paths, model, tag + "_agedb", det, norm)
        scores[label] = np.array([float(emb[str(a)] @ emb[str(b)]) for a, b, *_ in pairs])
        detected[label] = np.array([found[str(a)] and found[str(b)] for a, b, *_ in pairs])
        thresholds[label] = json.loads((RESULTS / tag / "metrics.json").read_text(encoding="utf-8"))[
            "verification"]["threshold_from_view1_train"]

    boot = IdentityBootstrap(people)

    def compare(keep):
        sub = [p for p, k in zip(pairs, keep) if k]
        yy = y[keep]
        s6, s3 = scores["C6"][keep], scores["C3"][keep]
        c6 = (s6 >= thresholds["C6"]) == yy
        c3 = (s3 >= thresholds["C3"]) == yy
        w = boot.weights(sub)
        auc_diff, acc_diff = [], []
        for row in w:
            k = row > 0
            if len(set(yy[k])) < 2:
                continue
            auc_diff.append(roc_auc_score(yy[k], s6[k], sample_weight=row[k])
                            - roc_auc_score(yy[k], s3[k], sample_weight=row[k]))
            acc_diff.append(np.average(c6[k], weights=row[k]) - np.average(c3[k], weights=row[k]))
        ci = lambda v: [float(np.percentile(v, 2.5)), float(np.percentile(v, 97.5))]
        return {
            "pairs": int(keep.sum()),
            "auc": {"C6": float(roc_auc_score(yy, s6)), "C3": float(roc_auc_score(yy, s3)),
                    "difference_C6_minus_C3": float(roc_auc_score(yy, s6) - roc_auc_score(yy, s3)),
                    "difference_ci95_identity_bootstrap": ci(auc_diff)},
            "accuracy_at_own_lfw_threshold": {
                "C6": float(c6.mean()), "C3": float(c3.mean()),
                "difference_C6_minus_C3": float(c6.mean() - c3.mean()),
                "difference_ci95_identity_bootstrap": ci(acc_diff)},
        }

    result = {
        "script_version": VERSION,
        "dataset": "AgeDB photo release, team-generated AgeDB-30-style pairs (seed 0); not the official AgeDB-30 protocol",
        "configs": {k: config_tag(*v) for k, v in CONFIGS.items()},
        "lfw_thresholds": thresholds,
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "all_photos": compare(np.ones(len(pairs), bool)),
        "face_detected_in_both_configs": compare(detected["C6"] & detected["C3"]),
        "note": "Paired identity-level bootstrap. A CI excluding 0 supports a difference on these pairs only.",
    }
    out = RESULTS / "agedb_comparison_C6_vs_C3.json"
    out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"\nSaved to {out}")


if __name__ == "__main__":
    main()
