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
  Main search results use only images where a face was detected (an evaluation
  assumption, not a Radd requirement); results including the no-face fallback are
  reported alongside for transparency.
  Also: event-sized galleries (50-1000 registered people, 20 random draws each) and
  an EXPLORATORY experiment averaging 3 photos per person vs 1 photo (Radd's
  requirements define one reference photo and one stored embedding).
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
EVENT_SIZES = (50, 100, 300, 1000)   # registered people in one simulated event
EVENT_REPEATS = 20
FPIRS = (0.01, 0.05)                 # target share of unregistered people wrongly matched


def search(P, G, true_idx):
    """P: probe embeddings, G: gallery embeddings, true_idx: correct gallery row per probe.
    Returns the correct person's score, whether they are ranked 1st, within the top 5."""
    S = P @ G.T
    true_s = S[np.arange(len(P)), true_idx]
    rank = (S > true_s[:, None]).sum(1)
    return true_s, rank == 0, rank < 5


def open_set(true_s, ok1, ok5, un_cal, un_test):
    """Search threshold set on one half of the unregistered people, tested on the other half."""
    out = {}
    for fpir in FPIRS:
        t = float(np.quantile(un_cal, 1 - fpir))
        out[f"target_false_alarm_{int(fpir*100)}pct"] = {
            "search_threshold": t,
            "unknown_wrongly_matched_on_test_half": float((un_test >= t).mean()),
            "known_found_first_and_above_threshold": float((ok1 & (true_s >= t)).mean()),
            "known_in_top5_and_above_threshold": float((ok5 & (true_s >= t)).mean()),
        }
    return out


def identification(paths, emb, found, verif_threshold, face_only):
    """Gallery = first image of each person with >= 2 images; known probes = up to 5 of
    their other images; unknown probes = people with a single image (never registered).
    face_only=True drops images where no face was detected (evaluation assumption only;
    the no-face handling in Radd is not defined by this script)."""
    people = {}
    for p in sorted(paths, key=str):
        if face_only and not found[str(p)]:
            continue
        people.setdefault(p.parent.name, []).append(str(p))
    gallery_names = [n for n, ps in people.items() if len(ps) >= 2]
    G = np.stack([emb[people[n][0]] for n in gallery_names])
    known = [(p, i) for i, n in enumerate(gallery_names) for p in people[n][1:6]]
    P = np.stack([emb[p] for p, _ in known])
    true_idx = np.array([i for _, i in known])
    U = np.stack([emb[people[n][0]] for n in sorted(n for n, ps in people.items() if len(ps) == 1)])

    true_s, ok1, ok5 = search(P, G, true_idx)
    SU = U @ G.T
    perm = RNG.permutation(len(U))
    cal, test = perm[: len(perm) // 2], perm[len(perm) // 2:]
    un_top = SU.max(1)
    res = {
        "images_used": sum(len(ps) for ps in people.values()),
        "gallery_people": len(gallery_names), "known_probes": len(known), "unknown_probes": len(U),
        "rank1": float(ok1.mean()), "rank1_ci95": boot_ci(lambda a: a.mean(), len(ok1), ok1),
        "top5": float(ok5.mean()), "top5_ci95": boot_ci(lambda a: a.mean(), len(ok5), ok5),
        "with_verification_threshold": {
            "threshold": verif_threshold,
            "unknown_correctly_rejected": float((un_top < verif_threshold).mean()),
        },
        "open_set": open_set(true_s, ok1, ok5, un_top[cal], un_top[test]),
    }
    if not face_only:
        return res

    # Event-sized galleries: matching compares against the registered people of one
    # Active event (PBI 15/16), so search with smaller galleries than all of LFW.
    events = {}
    for size in EVENT_SIZES:
        if size > len(gallery_names):
            continue
        runs = []
        for _ in range(EVENT_REPEATS):
            sel = np.sort(RNG.choice(len(gallery_names), size, replace=False))
            remap = -np.ones(len(gallery_names), int)
            remap[sel] = np.arange(size)
            rows = remap[true_idx] >= 0
            ts, o1, o5 = search(P[rows], G[sel], remap[true_idx[rows]])
            ut = SU[:, sel].max(1)
            runs.append({"rank1": o1.mean(), "top5": o5.mean(),
                         "open": open_set(ts, o1, o5, ut[cal], ut[test])})
        events[f"{size}_people"] = {
            "repeats": EVENT_REPEATS,
            "rank1_mean": float(np.mean([r["rank1"] for r in runs])),
            "top5_mean": float(np.mean([r["top5"] for r in runs])),
            "open_set_mean": {k: {m: float(np.mean([r["open"][k][m] for r in runs]))
                                  for m in runs[0]["open"][k]} for k in runs[0]["open"]},
        }
    res["event_sized_galleries"] = events

    # EXPLORATORY only, not a Radd requirement: several photos per person (mean
    # embedding) vs one photo, on the same people and probes.
    multi = [n for n, ps in people.items() if len(ps) >= 4]
    if multi:
        G1 = np.stack([emb[people[n][0]] for n in multi])
        G3 = np.stack([np.mean([emb[p] for p in people[n][:3]], 0) for n in multi])
        G3 /= np.linalg.norm(G3, axis=1, keepdims=True)
        mk = [(p, i) for i, n in enumerate(multi) for p in people[n][3:8]]
        Pm, tm = np.stack([emb[p] for p, _ in mk]), np.array([i for _, i in mk])
        _, a1, a5 = search(Pm, G1, tm)
        _, b1, b5 = search(Pm, G3, tm)
        res["exploratory_multi_photo_gallery"] = {
            "note": "exploratory experiment only; Radd requirements define one reference photo and one embedding",
            "people": len(multi), "probes": len(mk),
            "one_photo": {"rank1": float(a1.mean()), "top5": float(a5.mean())},
            "three_photos_averaged": {"rank1": float(b1.mean()), "rank1_ci95": boot_ci(lambda a: a.mean(), len(b1), b1),
                                      "top5": float(b5.mean())},
        }
    return res


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

    both = np.array([found[str(a)] and found[str(b)] for a, b in zip(view2.img1, view2.img2)])
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
            "view2_face_detected_pairs_only": {"pairs": int(both.sum()),
                                               **verification_block(s_v2[both], y_v2[both], t_dev)},
        },
        "identification": {
            "note": "face_detected_only excludes images where no face was detected (evaluation assumption, not a Radd requirement)",
            "face_detected_only": identification(paths, emb, found, t_dev, face_only=True),
            "all_images_incl_no_face_fallback": identification(paths, emb, found, t_dev, face_only=False),
        },
        "confidence_calibration": calibration(s_tr, y_tr, s_v2, y_v2),
    }

    if args.robustness:
        sub = view2[view2.fold.isin(folds[:3])]
        y_sub = sub.same.values
        f1 = np.array([found[str(p)] for p in sub.img1])

        def rob_block(s, f2):
            ok = f1 & f2
            return {"img2_no_face_rate": float(1 - f2.mean()),
                    "all_pairs": verification_block(s, y_sub, t_dev),
                    "face_detected_pairs_only": {"pairs": int(ok.sum()), **verification_block(s[ok], y_sub[ok], t_dev)}}

        rob = {"pairs": len(sub),
               "clean": rob_block(sims(sub, emb), np.array([found[str(p)] for p in sub.img2]))}
        for cond in CONDITIONS:
            sub = sub.assign(**{f"img2_{cond}": [f"{p}|{cond}" for p in sub.img2]})
            emb_c, found_c = embed_all(list(sub[f"img2_{cond}"]), args.model, cache + "_robust",
                                       args.detector, args.normalization)
            emb_all = {**emb, **emb_c}
            rob[cond] = rob_block(sims(sub, emb_all, f"img2_{cond}"),
                                  np.array([found_c[k] for k in sub[f"img2_{cond}"]]))
        metrics["robustness_view2_folds_1to3"] = rob

    out = RESULTS / tag
    out.mkdir(parents=True, exist_ok=True)
    name = "metrics_quick.json" if args.quick else "metrics.json"
    (out / name).write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print(f"\nSaved to {out / name}")


if __name__ == "__main__":
    main()
