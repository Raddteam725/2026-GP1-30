"""Radd face-matching evaluation on LFW for ONE model (PBI 13).

Usage (from the ai folder, with ai/.venv active):
    python scripts/evaluate_lfw.py --model ArcFace --quick   # 5-minute check that everything runs
    python scripts/evaluate_lfw.py --model ArcFace           # full run

Writes numbers only to results/<model>/metrics.json. Embeddings are cached in
embeddings/ (ignored by Git) so an interrupted run resumes where it stopped.
"""
import argparse
import json
import platform
import time
from datetime import datetime, timezone

import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score, roc_curve

from lfw_common import MODELS, DETECTOR, RESULTS, load_view1, load_view2, check_images, embed_all


def sims(df, emb):
    return np.array([float(emb[a] @ emb[b]) for a, b in zip(df.img1, df.img2)])


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


def identification(paths, emb, threshold, max_probes_per_person=5):
    """1:N search. Gallery: first image of every person with >= 2 images.
    Known probes: up to 5 other images of those people.
    Unknown probes: people with exactly 1 image (not in the gallery)."""
    people = {}
    for p in sorted(paths, key=str):
        people.setdefault(p.parent.name, []).append(p)
    gallery_names = [n for n, ps in people.items() if len(ps) >= 2]
    G = np.stack([emb[people[n][0]] for n in gallery_names])
    known = [(p, n) for n in gallery_names for p in people[n][1:1 + max_probes_per_person]]
    unknown = [ps[0] for n, ps in people.items() if len(ps) == 1]

    rank1 = top5 = dir_ok = 0
    for p, n in known:
        sc = G @ emb[p]
        order = np.argsort(-sc)
        top = [gallery_names[i] for i in order[:5]]
        rank1 += top[0] == n
        top5 += n in top
        dir_ok += (top[0] == n) and (sc[order[0]] >= threshold)
    rejected = sum(float((G @ emb[p]).max()) < threshold for p in unknown)
    return {
        "gallery_people": len(gallery_names),
        "known_probes": len(known),
        "unknown_probes": len(unknown),
        "rank1": rank1 / len(known),
        "top5": top5 / len(known),
        "correct_match_above_threshold": dir_ok / len(known),
        "unknown_correctly_rejected": (rejected / len(unknown)) if unknown else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, choices=MODELS)
    ap.add_argument("--quick", action="store_true", help="small subset, to check the pipeline runs")
    args = ap.parse_args()

    dev_train, dev_test, view2 = load_view1("DevTrain"), load_view1("DevTest"), load_view2()
    if args.quick:
        pick = lambda df, n: pd.concat([df[df.same == 1].head(n), df[df.same == 0].head(n)])
        dev_train, dev_test = pick(dev_train, 40), pick(dev_test, 20)
        view2 = pd.concat([pick(view2[view2.fold == k], 20) for k in range(2)])
    check_images(dev_train, dev_test, view2)

    paths = sorted(set(pd.concat([dev_train.img1, dev_train.img2, dev_test.img1, dev_test.img2,
                                  view2.img1, view2.img2])), key=str)
    t0 = time.perf_counter()
    emb, found = embed_all(paths, args.model, args.model + ("_quick" if args.quick else ""))
    embed_minutes = (time.perf_counter() - t0) / 60

    # Verification (1:1). Threshold chosen on View 1 train only.
    s_tr, y_tr = sims(dev_train, emb), dev_train.same.values
    t_dev, acc_dev_train = best_threshold(s_tr, y_tr)
    s_te, y_te = sims(dev_test, emb), dev_test.same.values
    s_v2, y_v2 = sims(view2, emb), view2.same.values

    # Standard View 2 protocol: for each fold, threshold from the other folds.
    folds = sorted(view2.fold.unique())
    fold_acc = []
    for k in folds:
        tr, te = (view2.fold != k).values, (view2.fold == k).values
        t_k, _ = best_threshold(s_v2[tr], y_v2[tr])
        fold_acc.append(accuracy(s_v2[te], y_v2[te], t_k))

    metrics = {
        "model": args.model,
        "detector": DETECTOR,
        "similarity": "cosine",
        "quick_run": args.quick,
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "machine": {"system": platform.system(), "processor": platform.processor(), "python": platform.python_version()},
        "images": {"total": len(paths), "no_face_detected": int(sum(not f for f in found.values()))},
        "embedding_minutes_total": round(embed_minutes, 2),
        "verification": {
            "threshold_from_view1_train": t_dev,
            "view1_train_accuracy": acc_dev_train,
            "view1_test_accuracy_at_threshold": accuracy(s_te, y_te, t_dev),
            "view2_accuracy_at_view1_threshold": accuracy(s_v2, y_v2, t_dev),
            "view2_10fold_accuracy_mean": float(np.mean(fold_acc)),
            "view2_10fold_accuracy_std": float(np.std(fold_acc)),
            "view2_folds_used": len(folds),
            "view2_auc": float(roc_auc_score(y_v2, s_v2)),
            "view2_tar_at_far_1pct": tar_at_far(s_v2, y_v2, 0.01),
        },
        "identification": identification(paths, emb, t_dev),
    }

    out = RESULTS / args.model
    out.mkdir(parents=True, exist_ok=True)
    name = "metrics_quick.json" if args.quick else "metrics.json"
    (out / name).write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print(f"\nSaved to {out / name}")


if __name__ == "__main__":
    main()
