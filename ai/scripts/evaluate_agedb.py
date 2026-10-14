"""Age-gap evaluation on AgeDB for one model configuration (PBI 13, confirmation).

Usage (from the ai folder, with ai/.venv active; photos in ai/data/agedb/):
    python scripts/evaluate_agedb.py --model Facenet512 --detector mtcnn --normalization Facenet2018 --quick
    python scripts/evaluate_agedb.py --model Facenet512 --detector mtcnn --normalization Facenet2018
    python scripts/evaluate_agedb.py --model ArcFace --normalization ArcFace

AgeDB photos are named <index>_<Name>_<age>_<gender>.jpg. The official AgeDB-30
pair list is not part of the photo release, so the team builds its own pairs in
the same style (fixed random seed, documented here):
- Same-person pairs: every pair of photos of one person with an age gap of at
  least 5 years, grouped by gap (5-9, 10-19, 20-29, 30+ years).
- Different-person pairs: random pairs of photos of two different people.
- People are split into 10 folds, so no person appears in both the folds used to
  choose a threshold and the fold used to test it.
Main protocol ("AgeDB-30 style"): 3,000 same-person pairs with a gap of 30+
years and 3,000 different-person pairs (fewer if not enough exist).

Also reported, at the threshold chosen on LFW View 1 for the same configuration
(how Radd would actually be configured): the share of same-person pairs accepted
for each age-gap group, and for pairs where the younger photo shows a child
(under 13) or a teenager (13-17).

Numbers only are written to results/<config>/agedb_metrics.json.
"""
import argparse
import json
import platform
import re
import time
from collections import defaultdict
from datetime import datetime, timezone
from itertools import combinations

import numpy as np
from sklearn.metrics import roc_auc_score, roc_curve

from lfw_common import (AI_DIR, MODELS, DETECTORS, NORMALIZATIONS, DEFAULT_DETECTOR,
                        DEFAULT_NORMALIZATION, RESULTS, config_tag, embed_all)

AGEDB = AI_DIR / "data" / "agedb"
NAME = re.compile(r"^(\d+)_(.+)_(\d+)_([mf])\.jpg$", re.IGNORECASE)
GAP_GROUPS = [(5, 9), (10, 19), (20, 29), (30, 200)]
RNG = np.random.default_rng(0)
N_BOOT = 1000


def load_photos():
    people = defaultdict(list)
    skipped = 0
    for p in sorted(AGEDB.rglob("*.jpg")):
        m = NAME.match(p.name)
        if not m:
            skipped += 1
            continue
        people[m.group(2)].append((p, int(m.group(3))))
    if not people:
        raise FileNotFoundError(f"No AgeDB photos found in {AGEDB}")
    return people, skipped


def build_pairs(people, n_main=3000, n_neg=3000, quick=False):
    names = sorted(people)
    fold_of = {n: i % 10 for i, n in enumerate(RNG.permutation(names))}
    same = []
    for n in names:
        for (p1, a1), (p2, a2) in combinations(people[n], 2):
            gap = abs(a1 - a2)
            if gap >= 5:
                same.append((p1, p2, gap, min(a1, a2), fold_of[n]))
    diff = []
    tries = 0
    while len(diff) < n_neg and tries < n_neg * 50:
        tries += 1
        a, b = RNG.choice(len(names), 2, replace=False)
        na, nb = names[a], names[b]
        if fold_of[na] != fold_of[nb]:
            continue  # keep each pair inside one fold
        pa = people[na][RNG.integers(len(people[na]))]
        pb = people[nb][RNG.integers(len(people[nb]))]
        diff.append((pa[0], pb[0], abs(pa[1] - pb[1]), min(pa[1], pb[1]), fold_of[na]))
    main_same = [s for s in same if s[2] >= 30]
    main_same = [main_same[i] for i in RNG.permutation(len(main_same))[:n_main]]
    if quick:
        same = [same[i] for i in RNG.permutation(len(same))[:300]]
        main_same = main_same[:100]
        diff = diff[:100]
    return same, main_same, diff


def tar_at_far(s, y, far):
    fpr, tpr, _ = roc_curve(y, s)
    ok = fpr <= far
    return float(tpr[ok].max()) if ok.any() else 0.0


def best_threshold(s, y):
    cand = np.unique(s)
    acc = [((s >= t) == y).mean() for t in cand]
    return float(cand[int(np.argmax(acc))])


def boot_ci(values):
    values = np.asarray(values, dtype=float)
    if len(values) == 0:
        return None
    means = [values[RNG.integers(0, len(values), len(values))].mean() for _ in range(N_BOOT)]
    return [float(np.percentile(means, 2.5)), float(np.percentile(means, 97.5))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, choices=MODELS)
    ap.add_argument("--detector", default=DEFAULT_DETECTOR, choices=DETECTORS)
    ap.add_argument("--normalization", default=DEFAULT_NORMALIZATION, choices=NORMALIZATIONS)
    ap.add_argument("--quick", action="store_true")
    args = ap.parse_args()
    tag = config_tag(args.model, args.detector, args.normalization)

    lfw_file = RESULTS / tag / "metrics.json"
    lfw_threshold = None
    if lfw_file.exists():
        lfw_threshold = json.loads(lfw_file.read_text(encoding="utf-8"))["verification"]["threshold_from_view1_train"]

    people, skipped = load_photos()
    same, main_same, diff = build_pairs(people, quick=args.quick)
    paths = sorted({str(x) for pairs in (same, main_same, diff) for p in pairs for x in p[:2]})
    cache = tag + "_agedb" + ("_quick" if args.quick else "")
    t0 = time.perf_counter()
    emb, found = embed_all(paths, args.model, cache, args.detector, args.normalization)
    minutes = (time.perf_counter() - t0) / 60

    sim = lambda pairs: np.array([float(emb[str(a)] @ emb[str(b)]) for a, b, *_ in pairs])
    s_main, s_diff = sim(main_same), sim(diff)
    s = np.concatenate([s_main, s_diff])
    y = np.concatenate([np.ones(len(s_main), bool), np.zeros(len(s_diff), bool)])
    folds = np.array([p[4] for p in main_same] + [p[4] for p in diff])

    fold_acc = []
    for k in range(10):
        tr, te = folds != k, folds == k
        if te.sum() == 0 or len(set(y[tr])) < 2:
            continue
        t = best_threshold(s[tr], y[tr])
        fold_acc.append(float(((s[te] >= t) == y[te]).mean()))

    main_block = {
        "same_person_pairs": len(s_main), "different_person_pairs": len(s_diff),
        "tenfold_accuracy_mean": float(np.mean(fold_acc)) if fold_acc else None,
        "tenfold_accuracy_std": float(np.std(fold_acc)) if fold_acc else None,
        "auc": float(roc_auc_score(y, s)),
        "tar_at_far_1pct": tar_at_far(s, y, 0.01),
    }
    if lfw_threshold is not None:
        correct = (s >= lfw_threshold) == y
        main_block["at_lfw_threshold"] = {
            "threshold": lfw_threshold,
            "accuracy": float(correct.mean()), "accuracy_ci95": boot_ci(correct),
            "same_person_accepted": float((s_main >= lfw_threshold).mean()),
            "different_person_wrongly_accepted": float((s_diff >= lfw_threshold).mean()),
        }

    breakdown = {}
    if lfw_threshold is not None:
        s_same = sim(same)
        gaps = np.array([p[2] for p in same]); young = np.array([p[3] for p in same])
        for lo, hi in GAP_GROUPS:
            sel = (gaps >= lo) & (gaps <= hi)
            acc = s_same[sel] >= lfw_threshold
            breakdown[f"gap_{lo}_{'plus' if hi >= 200 else hi}_years"] = {
                "pairs": int(sel.sum()), "same_person_accepted": float(acc.mean()) if sel.any() else None,
                "ci95": boot_ci(acc)}
        for label, sel in [("younger_photo_child_under_13", young < 13),
                           ("younger_photo_teen_13_17", (young >= 13) & (young < 18)),
                           ("younger_photo_adult_18_plus", young >= 18)]:
            acc = s_same[sel] >= lfw_threshold
            breakdown[label] = {"pairs": int(sel.sum()),
                                "same_person_accepted": float(acc.mean()) if sel.any() else None,
                                "ci95": boot_ci(acc)}

    metrics = {
        "dataset": "AgeDB (official photo release, team-generated pairs, seed 0)",
        "model": args.model, "detector": args.detector, "normalization": args.normalization, "config": tag,
        "quick_run": args.quick,
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "machine": {"system": platform.system(), "processor": platform.processor(), "python": platform.python_version()},
        "photos": {"people": len(people), "photos": sum(len(v) for v in people.values()),
                   "files_skipped_bad_name": skipped, "used": len(paths),
                   "no_face_detected": int(sum(not found[p] for p in paths))},
        "embedding_minutes": round(minutes, 2),
        "agedb30_style_protocol": main_block,
        "same_person_accepted_at_lfw_threshold_by_group": breakdown,
    }
    out = RESULTS / tag
    out.mkdir(parents=True, exist_ok=True)
    name = "agedb_metrics_quick.json" if args.quick else "agedb_metrics.json"
    (out / name).write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print(f"\nSaved to {out / name}")


if __name__ == "__main__":
    main()
