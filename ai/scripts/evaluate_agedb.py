"""Age-gap evaluation on AgeDB for one model configuration (PBI 13, confirmation). v2.

Usage (from the ai folder, with ai/.venv active; photos in ai/data/agedb/):
    python scripts/evaluate_agedb.py --model Facenet512 --detector mtcnn --normalization Facenet2018
    python scripts/evaluate_agedb.py --model ArcFace --normalization ArcFace
Embeddings are cached in ai/embeddings (ignored by Git), so a rerun on the same
photos only recomputes the numbers.

AgeDB photos are named <index>_<Name>_<age>_<gender>.jpg. The official AgeDB-30
pair list is NOT part of the photo release, so the team builds its own pairs.
These are team-generated pairs and are not comparable with published AgeDB-30
benchmark results. Differences from the official protocol are listed in the
output ("protocol_notes").

Identity: a person is identified by the <Name> part of the file name, the only
identity information in the release. The script prints a check of this grouping
(people per name cannot be separated if two subjects share a name).

Pairs (fixed seed 0; people split into 10 identity folds, so no person is in both
the folds used to choose a threshold and the fold used to test it):
- Same-person pairs: every pair of photos of one person with an age gap of at
  least 5 years, grouped by gap (5-9, 10-19, 20-29, 30+ years).
- Main protocol ("AgeDB-30 style"): 3,000 same-person pairs with a gap of 30+
  years and 3,000 different-person pairs whose two photos ALSO differ in age by
  30+ years (age-gap matched negatives). A variant with randomly sampled
  different-person pairs (the v1 protocol) is reported for comparison.

Two views of every result:
- all_photos: photos where no face is detected are embedded as a whole image
  (benchmark fallback, as in the LFW evaluation);
- face_detected_only: pairs where a face was detected in both photos. This
  matches the Radd backend, which stores no embedding when no face is detected.

Confidence intervals: identity-level bootstrap (people are resampled, not pairs),
because many pairs share the same person. Different-person pairs are weighted by
the product of both people's resampling counts.

AgeDB results are 1:1 verification at the LFW View 1 threshold of the same
configuration. They are not 1:N search results and do not validate Radd's search
threshold (0.596), which still requires integration testing.

Numbers only are written to results/<config>/agedb_metrics.json.
"""
import argparse
import json
import platform
import re
import time
from collections import Counter, defaultdict
from datetime import datetime, timezone
from itertools import combinations

import numpy as np
from sklearn.metrics import roc_auc_score, roc_curve

from lfw_common import (AI_DIR, MODELS, DETECTORS, NORMALIZATIONS, DEFAULT_DETECTOR,
                        DEFAULT_NORMALIZATION, RESULTS, config_tag, embed_all)

VERSION = "v2"
AGEDB = AI_DIR / "data" / "agedb"
NAME = re.compile(r"^(\d+)_(.+)_(\d+)_([mf])\.jpg$", re.IGNORECASE)
DOCUMENTED_SUBJECTS = 568
GAP_GROUPS = [(5, 9), (10, 19), (20, 29), (30, 200)]
YOUNG_GROUPS = [("child_under_13", 0, 12), ("teen_13_17", 13, 17), ("adult_18_plus", 18, 200)]
MAIN_GAP = 30
N_MAIN = N_NEG = 3000
N_BOOT = 1000

PROTOCOL_NOTES = [
    "Team-generated pairs (seed 0); the official AgeDB-30 pair list is not used.",
    "Identity = name in the file name; the release documents 568 subjects.",
    "Same-person pairs: age gap of 30+ years (official AgeDB-30 uses pairs at a gap of about 30 years).",
    "Different-person pairs: age gap of 30+ years, two different names, same identity fold.",
    "10 identity folds; threshold chosen on 9 folds, tested on the 10th.",
    "1:1 verification only; not 1:N search and not Radd's search threshold.",
]


# ---------- data ----------
def load_photos():
    people = defaultdict(list)
    genders = defaultdict(set)
    skipped = 0
    for p in sorted(AGEDB.rglob("*.jpg")):
        m = NAME.match(p.name)
        if not m:
            skipped += 1
            continue
        people[m.group(2)].append((p, int(m.group(3))))
        genders[m.group(2)].add(m.group(4).lower())
    if not people:
        raise FileNotFoundError(f"No AgeDB photos found in {AGEDB}")
    return people, genders, skipped


def identity_check(people, genders):
    """Counts only are saved; names are printed for a human check, never written to results."""
    counts = Counter({n: len(v) for n, v in people.items()})
    mixed = sorted(n for n, g in genders.items() if len(g) > 1)
    spans = {n: max(a for _, a in v) - min(a for _, a in v) for n, v in people.items()}
    print("\nIdentity check (names printed here only, not saved):")
    print(f"  distinct names: {len(people)} (AgeDB documents {DOCUMENTED_SUBJECTS} subjects)")
    print(f"  names with both genders in file names: {mixed or 'none'}")
    print(f"  most photos per name: {counts.most_common(5)}")
    print(f"  widest age span per name: {sorted(spans.items(), key=lambda x: -x[1])[:5]}")
    return {
        "distinct_names": len(people), "documented_subjects": DOCUMENTED_SUBJECTS,
        "names_with_both_genders": len(mixed),
        "median_photos_per_name": float(np.median(list(counts.values()))),
        "max_photos_per_name": int(max(counts.values())),
    }


def build_pairs(people):
    rng = np.random.default_rng(0)
    names = sorted(people)
    fold_of = {n: i % 10 for i, n in enumerate(rng.permutation(names))}
    by_fold = defaultdict(list)
    for n in names:
        by_fold[fold_of[n]].append(n)

    # pair = (photo1, photo2, gap, younger_age, fold, person1, person2)
    same = []
    for n in names:
        for (p1, a1), (p2, a2) in combinations(people[n], 2):
            if abs(a1 - a2) >= 5:
                same.append((p1, p2, abs(a1 - a2), min(a1, a2), fold_of[n], n, n))
    main_same = [s for s in same if s[2] >= MAIN_GAP]
    main_same = [main_same[i] for i in rng.permutation(len(main_same))[:N_MAIN]]

    def negatives(min_gap):
        out, tries = [], 0
        folds = sorted(by_fold)
        while len(out) < N_NEG and tries < N_NEG * 200:
            tries += 1
            f = folds[rng.integers(len(folds))]
            if len(by_fold[f]) < 2:
                continue
            a, b = rng.choice(len(by_fold[f]), 2, replace=False)
            na, nb = by_fold[f][a], by_fold[f][b]
            pa, aa = people[na][rng.integers(len(people[na]))]
            options = [(p, ab) for p, ab in people[nb] if abs(ab - aa) >= min_gap]
            if not options:
                continue
            pb, ab = options[rng.integers(len(options))]
            out.append((pa, pb, abs(aa - ab), min(aa, ab), f, na, nb))
        return out

    neg_matched = negatives(MAIN_GAP)
    neg_random = negatives(0)
    return same, main_same, neg_matched, neg_random


# ---------- metrics ----------
def best_threshold(s, y):
    cand = np.unique(s)
    acc = [((s >= t) == y).mean() for t in cand]
    return float(cand[int(np.argmax(acc))])


def tar_at_far(s, y, far):
    fpr, tpr, _ = roc_curve(y, s)
    ok = fpr <= far
    return float(tpr[ok].max()) if ok.any() else 0.0


class IdentityBootstrap:
    """Resamples people with replacement; each pair is weighted by how often its
    people were drawn (same-person: count; different-person: product of counts)."""

    def __init__(self, names, seed=1):
        self.index = {n: i for i, n in enumerate(sorted(names))}
        rng = np.random.default_rng(seed)
        n = len(self.index)
        self.draws = np.stack([np.bincount(rng.integers(0, n, n), minlength=n) for _ in range(N_BOOT)])

    def weights(self, pairs):
        a = np.array([self.index[p[5]] for p in pairs])
        b = np.array([self.index[p[6]] for p in pairs])
        same = a == b
        w = self.draws[:, a].astype(float)
        w[:, ~same] *= self.draws[:, b[~same]]
        return w  # shape (N_BOOT, pairs)

    def ci(self, pairs, values):
        """CI of a mean over pairs. Pairs sharing the same people are summed first,
        so ~200,000 same-person pairs only need one column per person."""
        if len(pairs) == 0:
            return None
        n = len(self.index)
        keys = np.array([self.index[p[5]] * n + self.index[p[6]] for p in pairs])
        uniq, inv = np.unique(keys, return_inverse=True)
        sums = np.bincount(inv, weights=np.asarray(values, float), minlength=len(uniq))
        counts = np.bincount(inv, minlength=len(uniq)).astype(float)
        a, b = uniq // n, uniq % n
        w = self.draws[:, a].astype(float)
        w[:, a != b] *= self.draws[:, b[a != b]]
        tot = w @ counts
        stats = (w @ sums)[tot > 0] / tot[tot > 0]
        return [float(np.percentile(stats, 2.5)), float(np.percentile(stats, 97.5))]

    def auc_ci(self, pairs, s, y):
        w = self.weights(pairs)
        stats = []
        for row in w:
            keep = row > 0
            if len(set(y[keep])) == 2:
                stats.append(roc_auc_score(y[keep], s[keep], sample_weight=row[keep]))
        return [float(np.percentile(stats, 2.5)), float(np.percentile(stats, 97.5))]


def protocol_block(pos, neg, score, boot, lfw_threshold):
    pairs = pos + neg
    s = np.array([score(p) for p in pairs])
    y = np.array([True] * len(pos) + [False] * len(neg))
    folds = np.array([p[4] for p in pairs])
    fold_acc = []
    for k in range(10):
        tr, te = folds != k, folds == k
        if te.sum() == 0 or len(set(y[tr])) < 2:
            continue
        t = best_threshold(s[tr], y[tr])
        fold_acc.append(float(((s[te] >= t) == y[te]).mean()))
    block = {
        "same_person_pairs": len(pos), "different_person_pairs": len(neg),
        "tenfold_accuracy_mean": float(np.mean(fold_acc)) if fold_acc else None,
        "tenfold_accuracy_std": float(np.std(fold_acc)) if fold_acc else None,
        "auc": float(roc_auc_score(y, s)) if len(set(y)) == 2 else None,
        "auc_ci95_identity_bootstrap": boot.auc_ci(pairs, s, y) if len(set(y)) == 2 else None,
        "tar_at_far_1pct": tar_at_far(s, y, 0.01) if len(set(y)) == 2 else None,
    }
    if lfw_threshold is not None:
        correct = (s >= lfw_threshold) == y
        accepted_pos = s[y] >= lfw_threshold
        accepted_neg = s[~y] >= lfw_threshold
        block["at_lfw_threshold"] = {
            "threshold": lfw_threshold,
            "accuracy": float(correct.mean()),
            "accuracy_ci95_identity_bootstrap": boot.ci(pairs, correct),
            "same_person_accepted": float(accepted_pos.mean()),
            "same_person_accepted_ci95": boot.ci(pos, accepted_pos),
            "different_person_wrongly_accepted": float(accepted_neg.mean()),
            "different_person_wrongly_accepted_ci95": boot.ci(neg, accepted_neg),
        }
    return block


def breakdown(same, score, boot, threshold):
    out = {}
    if threshold is None:
        return out
    s = np.array([score(p) for p in same])
    acc = s >= threshold
    gaps = np.array([p[2] for p in same])
    young = np.array([p[3] for p in same])

    def entry(sel):
        sub = [p for p, k in zip(same, sel) if k]
        return {"pairs": int(sel.sum()),
                "same_person_accepted": float(acc[sel].mean()) if sel.any() else None,
                "ci95_identity_bootstrap": boot.ci(sub, acc[sel])}

    gap_sel = {f"gap_{lo}_{'plus' if hi >= 200 else hi}_years": (gaps >= lo) & (gaps <= hi)
               for lo, hi in GAP_GROUPS}
    for label, sel in gap_sel.items():
        out[label] = entry(sel)
    for label, lo, hi in YOUNG_GROUPS:
        sel = (young >= lo) & (young <= hi)
        out[f"younger_photo_{label}"] = entry(sel)
        # Same group split by age gap, to separate childhood from the length of the gap.
        out[f"younger_photo_{label}_by_gap"] = {g: entry(sel & gs) for g, gs in gap_sel.items()}
    return out


# ---------- main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, choices=MODELS)
    ap.add_argument("--detector", default=DEFAULT_DETECTOR, choices=DETECTORS)
    ap.add_argument("--normalization", default=DEFAULT_NORMALIZATION, choices=NORMALIZATIONS)
    args = ap.parse_args()
    tag = config_tag(args.model, args.detector, args.normalization)

    lfw_file = RESULTS / tag / "metrics.json"
    lfw_threshold = None
    if lfw_file.exists():
        lfw_threshold = json.loads(lfw_file.read_text(encoding="utf-8"))["verification"]["threshold_from_view1_train"]
    else:
        print(f"Warning: {lfw_file} not found; results at the LFW threshold are skipped.")

    people, genders, skipped = load_photos()
    ids = identity_check(people, genders)
    same, main_same, neg_matched, neg_random = build_pairs(people)
    paths = sorted({str(x) for pairs in (same, main_same, neg_matched, neg_random) for p in pairs for x in p[:2]})
    t0 = time.perf_counter()
    emb, found = embed_all(paths, args.model, tag + "_agedb", args.detector, args.normalization)
    minutes = (time.perf_counter() - t0) / 60

    score = lambda p: float(emb[str(p[0])] @ emb[str(p[1])])
    detected = lambda pairs: [p for p in pairs if found[str(p[0])] and found[str(p[1])]]
    boot = IdentityBootstrap(people)

    def views(fn):
        return {"all_photos": fn(lambda x: x), "face_detected_only": fn(detected)}

    metrics = {
        "script_version": VERSION,
        "dataset": "AgeDB photo release, team-generated pairs (seed 0); not the official AgeDB-30 protocol",
        "protocol_notes": PROTOCOL_NOTES,
        "model": args.model, "detector": args.detector, "normalization": args.normalization, "config": tag,
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "machine": {"system": platform.system(), "processor": platform.processor(), "python": platform.python_version()},
        "photos": {"distinct_names": len(people), "photos": sum(len(v) for v in people.values()),
                   "files_skipped_bad_name": skipped, "used": len(paths),
                   "no_face_detected": int(sum(not found[p] for p in paths))},
        "identity_check": ids,
        "embedding_minutes": round(minutes, 2),
        "agedb30_style_protocol": views(lambda f: protocol_block(f(main_same), f(neg_matched), score, boot, lfw_threshold)),
        "variant_random_negatives": views(lambda f: protocol_block(f(main_same), f(neg_random), score, boot, lfw_threshold)),
        "same_person_accepted_at_lfw_threshold_by_group": views(lambda f: breakdown(f(same), score, boot, lfw_threshold)),
        "interpretation_limits": [
            "Children: pairs compare a photo taken before age 13 with a photo of the same person at least 5 years later; "
            "this is not Radd's same-event identification accuracy for children.",
            "1:1 verification only; it does not measure 1:N search or validate Radd's search threshold.",
        ],
    }
    out = RESULTS / tag
    out.mkdir(parents=True, exist_ok=True)
    (out / "agedb_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps(metrics["agedb30_style_protocol"], indent=2))
    print(f"\nSaved to {out / 'agedb_metrics.json'}")


if __name__ == "__main__":
    main()
