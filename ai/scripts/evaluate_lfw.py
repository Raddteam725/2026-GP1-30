"""Radd face-matching evaluation on LFW for ONE model configuration (PBI 13).

Usage (from the ai folder, with ai/.venv active):
    python scripts/evaluate_lfw.py --model ArcFace --quick                    # pipeline check
    python scripts/evaluate_lfw.py --model ArcFace                            # main evaluation
    python scripts/evaluate_lfw.py --model ArcFace --normalization ArcFace    # model-specific preprocessing
    python scripts/evaluate_lfw.py --model ArcFace --detector mtcnn           # other face detector
    python scripts/evaluate_lfw.py --model ArcFace --robustness               # + simulated field photos

What it measures
- Verification (1:1): threshold chosen on LFW View 1 train; accuracy, AUC and
  TAR at 1% / 0.1% FAR on View 2 (standard 10-fold protocol), with 95% bootstrap CIs.
- Identification (1:N): gallery = first image of each person with >= 2 images;
  known probes = up to 5 other images per person; unknown probes = people with a
  single image (never in the gallery). Rank-1 / Top-5, plus open-set results with a
  search threshold calibrated on half of the unknown people and tested on the other half.
- Confidence: a logistic calibration (similarity -> probability of same person)
  fitted on View 1 train, checked on View 2 (Brier score, expected calibration error).
- Robustness (optional): View 2 folds 1-3 with the second photo blurred, low
  resolution, dark or heavily compressed.

Writes numbers only to results/<config>/metrics.json. Embeddings are cached in
embeddings/ (ignored by Git), so interrupted runs resume and repeated runs reuse them.
"""
import argparse
import json
import platform
import time
from datetime import datetime, timezone

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score, roc_curve

from lfw_common import (MODELS, DETECTORS, NORMALIZATIONS, CONDITIONS, DEFAULT_DETECTOR,
                        DEFAULT_NORMALIZATION, RESULTS, config_tag, load_view1, load_view2,
                        check_images, embed_all)

RNG = np.random.default_rng(0)
N_BOOT = 1000


# ---------- verification helpers ----------
def sims(df, emb, col2="img2"):
    return np.array([float(emb[str(a)] @ emb[str(b)]) for a, b in zip(df.img1, df[col2])])


def best_threshold(s, y):
    """Threshold on cosine similarity that maximises accuracy (same person if s >= t)."""
    cand = np.unique(s)
    cand = np.concatenate([cand, [cand[-1] + 1e-6]])
    acc = [((s >= t) == y).mean() for t in cand]
    i = int(np.argmax(acc))
    return float(cand[i]), float(acc[i])


def accuracy(s, y, t):
    return float(((s >= t) == y).mean())


def tar_at_far(s, y, far):
    fpr, tpr, _ = roc_curve(y, s)
    ok = fpr <= far
    return float(tpr[ok].max()) if ok.any() else 0.0


def boot_ci(fn, n, *arrays):
    """95% bootstrap confidence interval of fn(*arrays) resampling n items."""
    vals = []
    for _ in range(N_BOOT):
        idx = RNG.integers(0, n, n)
        try:
            vals.append(fn(*[a[idx] for a in arrays]))
        except ValueError:      # e.g. a resample with only one class
            continue
    return [float(np.percentile(vals, 2.5)), float(np.percentile(vals, 97.5))]


def verification_block(s, y, t):
    return {
        "accuracy_at_threshold": accuracy(s, y, t),
        "accuracy_ci95": boot_ci(lambda a, b: accuracy(a, b, t), len(s), s, y),
        "auc": float(roc_auc_score(y, s)),
        "tar_at_far_1pct": tar_at_far(s, y, 0.01),
        "tar_at_far_0_1pct": tar_at_far(s, y, 0.001),
    }


# ---------- identification ----------
def identification(paths, emb, verif_threshold):
    people = {}
    for p in sorted(paths, key=str):
        people.setdefault(p.parent.name, []).append(str(p))
    gallery_names = [n for n, ps in people.items() if len(ps) >= 2]
    G = np.stack([emb[people[n][0]] for n in gallery_names])
    known = [(p, n) for n in gallery_names for p in people[n][1:6]]
    unknown_people = sorted(n for n, ps in people.items() if len(ps) == 1)
    unknown = [people[n][0] for n in unknown_people]

    kn_top, kn_ok1, kn_ok5 = [], [], []
    for p, n in known:
        sc = G @ emb[p]
        order = np.argsort(-sc)
        top = [gallery_names[i] for i in order[:5]]
        kn_top.append(float(sc[order[0]]))
        kn_ok1.append(top[0] == n)
        kn_ok5.append(n in top)
    kn_top, kn_ok1, kn_ok5 = map(np.array, (kn_top, kn_ok1, kn_ok5))
    un_top = np.array([float((G @ emb[p]).max()) for p in unknown])

    # Search threshold: calibrate on half of the unknown people, test on the other half.
    perm = RNG.permutation(len(un_top))
    cal, test = un_top[perm[: len(perm) // 2]], un_top[perm[len(perm) // 2:]]
    open_set = {}
    for fpir in (0.01, 0.05):
        t = float(np.quantile(cal, 1 - fpir))
        open_set[f"target_false_alarm_{int(fpir*100)}pct"] = {
            "search_threshold": t,
            "unknown_wrongly_matched_on_test_half": float((test >= t).mean()),
            "known_found_first_and_above_threshold": float((kn_ok1 & (kn_top >= t)).mean()),
        }
    return {
        "gallery_people": len(gallery_names),
        "known_probes": len(known),
        "unknown_probes": len(unknown),
        "rank1": float(kn_ok1.mean()),
        "rank1_ci95": boot_ci(lambda a: a.mean(), len(kn_ok1), kn_ok1),
        "top5": float(kn_ok5.mean()),
        "top5_ci95": boot_ci(lambda a: a.mean(), len(kn_ok5), kn_ok5),
        "with_verification_threshold": {
            "threshold": verif_threshold,
            "unknown_correctly_rejected": float((un_top < verif_threshold).mean()),
        },
        "open_set": open_set,
    }


# ---------- confidence calibration ----------
def calibration(s_tr, y_tr, s_te, y_te):
    lr = LogisticRegression().fit(s_tr.reshape(-1, 1), y_tr)

    def sim_for(q):     # None = that confidence is never reached (cosine similarity is at most 1)
        v = float((np.log(q / (1 - q)) - lr.intercept_[0]) / lr.coef_[0][0])
        return v if -1 <= v <= 1 else None

    p = lr.predict_proba(s_te.reshape(-1, 1))[:, 1]
    bins = np.clip((p * 10).astype(int), 0, 9)
    ece = sum(abs(p[bins == b].mean() - y_te[bins == b].mean()) * (bins == b).mean()
              for b in range(10) if (bins == b).any())
    return {
        "method": "logistic regression on cosine similarity, fitted on View 1 train",
        "coef": float(lr.coef_[0][0]), "intercept": float(lr.intercept_[0]),
        "view2_brier_score": float(np.mean((p - y_te) ** 2)),
        "view2_expected_calibration_error": float(ece),
        "similarity_for_probability": {f"{q:.2f}": sim_for(q) for q in (0.5, 0.8, 0.9, 0.95, 0.99)},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, choices=MODELS)
    ap.add_argument("--detector", default=DEFAULT_DETECTOR, choices=DETECTORS)
    ap.add_argument("--normalization", default=DEFAULT_NORMALIZATION, choices=NORMALIZATIONS)
    ap.add_argument("--robustness", action="store_true", help="also test simulated field-photo conditions")
    ap.add_argument("--quick", action="store_true", help="small subset, to check the pipeline runs")
    args = ap.parse_args()
    tag = config_tag(args.model, args.detector, args.normalization)

    dev_train, dev_test, view2 = load_view1("DevTrain"), load_view1("DevTest"), load_view2()
    if args.quick:
        pick = lambda df, n: pd.concat([df[df.same == 1].head(n), df[df.same == 0].head(n)])
        dev_train, dev_test = pick(dev_train, 40), pick(dev_test, 20)
        view2 = pd.concat([pick(view2[view2.fold == k], 20) for k in range(3)])
    check_images(dev_train, dev_test, view2)

    paths = sorted(set(pd.concat([dev_train.img1, dev_train.img2, dev_test.img1, dev_test.img2,
                                  view2.img1, view2.img2])), key=str)
    cache = tag + ("_quick" if args.quick else "")
    t0 = time.perf_counter()
    emb, found = embed_all(paths, args.model, cache, args.detector, args.normalization)
    embed_minutes = (time.perf_counter() - t0) / 60

    s_tr, y_tr = sims(dev_train, emb), dev_train.same.values
    t_dev, acc_dev_train = best_threshold(s_tr, y_tr)
    s_te, y_te = sims(dev_test, emb), dev_test.same.values
    s_v2, y_v2 = sims(view2, emb), view2.same.values

    folds = sorted(view2.fold.unique())
    fold_acc = []
    for k in folds:
        tr, te = (view2.fold != k).values, (view2.fold == k).values
        t_k, _ = best_threshold(s_v2[tr], y_v2[tr])
        fold_acc.append(accuracy(s_v2[te], y_v2[te], t_k))

    metrics = {
        "model": args.model, "detector": args.detector, "normalization": args.normalization,
        "config": tag, "similarity": "cosine", "quick_run": args.quick,
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "machine": {"system": platform.system(), "processor": platform.processor(), "python": platform.python_version()},
        "images": {"total": len(paths), "no_face_detected": int(sum(not f for f in found.values()))},
        "embedding_minutes_total": round(embed_minutes, 2),
        "verification": {
            "threshold_from_view1_train": t_dev,
            "view1_train_accuracy": acc_dev_train,
            "view1_test_accuracy_at_threshold": accuracy(s_te, y_te, t_dev),
            "view2_10fold_accuracy_mean": float(np.mean(fold_acc)),
            "view2_10fold_accuracy_std": float(np.std(fold_acc)),
            "view2_folds_used": len(folds),
            "view2_at_view1_threshold": verification_block(s_v2, y_v2, t_dev),
        },
        "identification": identification(paths, emb, t_dev),
        "confidence_calibration": calibration(s_tr, y_tr, s_v2, y_v2),
    }

    if args.robustness:
        sub = view2[view2.fold.isin(folds[:3])]
        y_sub = sub.same.values
        clean = verification_block(sims(sub, emb), y_sub, t_dev)
        rob = {"pairs": len(sub), "clean": clean}
        for cond in CONDITIONS:
            sub = sub.assign(**{f"img2_{cond}": [f"{p}|{cond}" for p in sub.img2]})
            emb_c, _ = embed_all(list(sub[f"img2_{cond}"]), args.model, cache + "_robust",
                                 args.detector, args.normalization)
            emb_all = {**emb, **emb_c}
            rob[cond] = verification_block(sims(sub, emb_all, f"img2_{cond}"), y_sub, t_dev)
        metrics["robustness_view2_folds_1to3"] = rob

    out = RESULTS / tag
    out.mkdir(parents=True, exist_ok=True)
    name = "metrics_quick.json" if args.quick else "metrics.json"
    (out / name).write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print(f"\nSaved to {out / name}")


if __name__ == "__main__":
    main()
