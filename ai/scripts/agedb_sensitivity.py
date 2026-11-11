"""AgeDB sensitivity check: do the results change without the names flagged in the identity check?

AgeDB identity is known only from the name in each file name. evaluate_agedb.py flags the
names whose file names carry both genders (possible label errors, or two people sharing a
name). This script rebuilds exactly the same pairs (seed 0) as evaluate_agedb.py, removes
every pair that involves a flagged name, and recomputes the main results for each
configuration, next to the results on all pairs.

Usage (from the repository folder). Only cached embeddings are used (nothing is recomputed):
evaluate_agedb.py must have run for each configuration. Cached embeddings are matched by photo
file name, so a cache made in another copy of the repository works too (--embeddings):
    python ai/scripts/agedb_sensitivity.py
    python ai/scripts/agedb_sensitivity.py --embeddings ai/embeddings ~/Desktop/Radd/ai/embeddings

Writes ai/results/agedb_sensitivity_flagged_names.json (numbers only; names are never
written or printed).
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from sklearn.metrics import roc_auc_score

from evaluate_agedb import (RESULTS, VERSION, IdentityBootstrap, breakdown, build_pairs, load_photos,
                            protocol_block)
from lfw_common import EMB_DIR, config_tag

CONFIGS = {"C3": ("ArcFace", "yunet", "ArcFace"),
           "C6": ("Facenet512", "mtcnn", "Facenet2018"),
           "C7": ("ArcFaceR50", "mtcnn", "base")}


def cached_embeddings(tag, folders, paths):
    """Embeddings and face-found flags from evaluate_agedb.py's cache, matched by file name."""
    for folder in folders:
        f = Path(folder).expanduser() / f"{tag}_agedb.npz"
        if f.exists():
            z = np.load(f, allow_pickle=False)
            by_name = {Path(k).name: (e, bool(ok)) for k, e, ok in zip(z["paths"], z["emb"], z["found"])}
            missing = [p for p in paths if Path(p).name not in by_name]
            if missing:
                raise SystemExit(f"{f} lacks {len(missing)} photos; run evaluate_agedb.py for {tag} first.")
            print(f"{tag}: embeddings from {f}")
            return ({p: by_name[Path(p).name][0] for p in paths}, {p: by_name[Path(p).name][1] for p in paths})
    raise SystemExit(f"No cached AgeDB embeddings for {tag} in {', '.join(map(str, folders))}; "
                     f"run evaluate_agedb.py for it first or pass --embeddings.")


def lfw_threshold(tag):
    f = RESULTS / tag / "metrics.json"
    return json.loads(f.read_text(encoding="utf-8"))["verification"]["threshold_from_view1_train"] if f.exists() else None


def summary(block):
    at = block.get("at_lfw_threshold", {})
    return {
        "same_person_pairs": block["same_person_pairs"],
        "different_person_pairs": block["different_person_pairs"],
        "tenfold_accuracy": block["tenfold_accuracy_mean"],
        "auc": block["auc"],
        "auc_ci95": block["auc_ci95_identity_bootstrap"],
        "tar_at_far_1pct": block["tar_at_far_1pct"],
        "accuracy_at_lfw_threshold": at.get("accuracy"),
        "same_person_accepted": at.get("same_person_accepted"),
        "different_person_wrongly_accepted": at.get("different_person_wrongly_accepted"),
    }


def children(groups):
    out = {"all_gaps": groups.get("younger_photo_child_under_13", {}).get("same_person_accepted")}
    for gap, entry in groups.get("younger_photo_child_under_13_by_gap", {}).items():
        out[gap] = entry.get("same_person_accepted")
    return out


def pct(x):
    return "  n/a" if x is None else f"{100 * x:5.1f}"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--configs", nargs="+", default=list(CONFIGS), choices=list(CONFIGS))
    ap.add_argument("--embeddings", nargs="+", default=[str(EMB_DIR), "~/Desktop/Radd/ai/embeddings"],
                    help="folders searched, in order, for <config>_agedb.npz")
    args = ap.parse_args()

    people, genders, _ = load_photos()
    flagged = {n for n, g in genders.items() if len(g) > 1}
    same, main_same, neg_matched, _ = build_pairs(people)
    clean = lambda pairs: [p for p in pairs if p[5] not in flagged and p[6] not in flagged]
    subsets = {"all_pairs": (same, main_same, neg_matched),
               "excluding_flagged_names": (clean(same), clean(main_same), clean(neg_matched))}
    boot = IdentityBootstrap(people)
    paths = sorted({str(x) for pairs in (same, main_same, neg_matched) for p in pairs for x in p[:2]})
    print(f"Flagged names: {len(flagged)} (not printed). Main protocol pairs removed: "
          f"{len(main_same) - len(subsets['excluding_flagged_names'][1])} same-person, "
          f"{len(neg_matched) - len(subsets['excluding_flagged_names'][2])} different-person.")

    results, scores = {}, {}
    for label in args.configs:
        model, det, norm = CONFIGS[label]
        tag = config_tag(model, det, norm)
        emb, found = cached_embeddings(tag, args.embeddings, paths)
        score = lambda p, e=emb: float(e[str(p[0])] @ e[str(p[1])])
        detected = lambda pairs, f=found: [p for p in pairs if f[str(p[0])] and f[str(p[1])]]
        t = lfw_threshold(tag)
        results[label] = {"config": tag, "lfw_threshold": t}
        scores[label] = (score, detected)
        for name, (s_all, s_main, s_neg) in subsets.items():
            results[label][name] = {}
            for view, f in (("all_photos", lambda x: x), ("face_detected_only", detected)):
                block = protocol_block(f(s_main), f(s_neg), score, boot, t)
                results[label][name][view] = {
                    "agedb30_style": summary(block),
                    "children_same_person_accepted_at_lfw_threshold": children(breakdown(f(s_all), score, boot, t)),
                }

    # Point differences between configurations on identical pairs, with and without the flagged names.
    differences = {}
    for a, b in (("C6", "C3"), ("C7", "C6")):
        if a in scores and b in scores:
            differences[f"{a}_minus_{b}"] = {}
            for name, (_, s_main, s_neg) in subsets.items():
                pairs = s_main + s_neg
                ok_a, ok_b = set(scores[a][1](pairs)), set(scores[b][1](pairs))
                both = [p for p in pairs if p in ok_a and p in ok_b]
                entry = {}
                for view, sel in (("all_photos", pairs), ("face_detected_in_both_configs", both)):
                    y = np.array([p[5] == p[6] for p in sel])
                    auc = {c: roc_auc_score(y, [scores[c][0](p) for p in sel]) for c in (a, b)}
                    entry[view] = {"pairs": len(sel), "auc_difference": auc[a] - auc[b]}
                differences[f"{a}_minus_{b}"][name] = entry

    out = {
        "script_version": VERSION + "-sensitivity1",
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "what": "Same team-generated pairs as evaluate_agedb.py (seed 0), with and without every pair that "
                "involves a name flagged by the identity check (both genders in its file names).",
        "flagged_names": len(flagged),
        "pairs": {name: {"same_person_all_gaps": len(s[0]), "main_same_person": len(s[1]),
                         "main_different_person": len(s[2])} for name, s in subsets.items()},
        "results": results,
        "differences_on_identical_pairs": differences,
    }
    RESULTS.mkdir(parents=True, exist_ok=True)
    path = RESULTS / "agedb_sensitivity_flagged_names.json"
    path.write_text(json.dumps(out, indent=2), encoding="utf-8")

    print("\nAgeDB-30 style, all photos: all pairs -> excluding flagged names")
    print("  config | 10-fold acc     | AUC             | TAR@1%FAR       | acc @ LFW thr   | wrong accepted  | children accepted")
    for label, r in results.items():
        a = r["all_pairs"]["all_photos"]
        e = r["excluding_flagged_names"]["all_photos"]
        row = [f"  {label:6}"]
        for key in ("tenfold_accuracy", "auc", "tar_at_far_1pct", "accuracy_at_lfw_threshold",
                    "different_person_wrongly_accepted"):
            x, y = a["agedb30_style"][key], e["agedb30_style"][key]
            row.append(f"{x:.3f} -> {y:.3f}" if key == "auc" else f"{pct(x)} -> {pct(y)}")
        row.append(f"{pct(a['children_same_person_accepted_at_lfw_threshold']['all_gaps'])} -> "
                   f"{pct(e['children_same_person_accepted_at_lfw_threshold']['all_gaps'])}")
        print(" | ".join(row))
    for k, v in differences.items():
        print(f"\n  AUC difference {k.replace('_minus_', ' - ')}: "
              + "; ".join(f"{name}: all photos {d['all_photos']['auc_difference']:+.3f}, face detected in both "
                          f"{d['face_detected_in_both_configs']['auc_difference']:+.3f}" for name, d in v.items()))
    print(f"\nSaved {path}")


if __name__ == "__main__":
    main()
