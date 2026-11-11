"""Held-out check of the age rules on UTKFace: are the thresholds over-fitted to the data
they were read from?

The age rules in backend/app/face_config.py were read from UTKFace tables computed on all
the photos (radd_utkface_diagnose.py, radd_margin_test.py). This script separates choosing
from measuring:

1. Same photos as before (seed 0, up to --per-band per age group, cached embeddings).
2. Probable duplicates (pairs scoring >= --dup) are removed within each age group FIRST, so a
   duplicate pair can never be split across the two halves.
3. The remaining photos are split at random into two halves. On one half (calibration) a
   threshold is chosen with a fixed, written-down rule: the lowest threshold (0.01 steps)
   whose wrong-person rate with --gallery registered people is <= --target %. Everything is
   then measured on the OTHER half (test) only: probes and galleries both come from it.
4. Repeated for --splits random splits, in both directions.

Reported per age group, on the test halves only:
- the app's rule exactly as configured (threshold + clear-winner for ages 0-5);
- the threshold chosen on the calibration half, and the same rule with that threshold.
Spread over runs shows how stable the numbers are; the Wilson 95% CI is given for the first run.

Usage (from the repository folder; uses the cached UTKFace embeddings, nothing is re-embedded):
  python ai/scripts/radd_utkface_holdout.py --utk ai/data/utkface
"""
import argparse
import random
import sys
from datetime import datetime
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import radd_engines  # noqa: E402
from radd_model_compare import Cache, embed_all, wilson  # noqa: E402
from radd_utkface_diagnose import AGE, SUB_BANDS, dedupe  # noqa: E402

# The app's rules (backend/app/face_config.py AGE_RULES): threshold, clear-winner floor, gap.
APP_RULES = {'child 0-2': (0.65, 0.45, 0.25), 'child 3-5': (0.60, 0.45, 0.15),
             'child 6-12': (0.38, None, None), 'teen 13-17': (0.38, None, None),
             'adult 18-59': (0.30, None, None), 'senior 60+': (0.38, None, None)}
GALLERIES = [10, 50, 100]
GRID = np.round(np.arange(0.20, 0.901, 0.01), 2)


def log(text=''):
    print(text, flush=True)


def impostor_searches(mat, n, seed, probes=1500):
    """Top-1 and top-2 wrong-person scores for searches of each probe against n other photos."""
    rng = random.Random(seed)
    m = len(mat)
    if m <= n + 1:
        return None, None
    idx = rng.sample(range(m), min(probes, m))
    top1, top2 = [], []
    for i in idx:
        others = [j for j in rng.sample(range(m), n + 1) if j != i][:n]
        s = np.sort(mat[others] @ mat[i])[::-1]
        top1.append(s[0])
        top2.append(s[1])
    return np.array(top1), np.array(top2)


def shown(rule, top1, top2):
    t, floor, gap = rule
    out = top1 >= t
    if floor is not None:
        out |= (top1 >= floor) & (top1 - top2 >= gap)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--utk', required=True)
    ap.add_argument('--engine', default='arcface')
    ap.add_argument('--per-band', type=int, default=1500)
    ap.add_argument('--dup', type=float, default=0.80)
    ap.add_argument('--target', type=float, default=3.0, help='wrong-person rate (%%) the chosen threshold may not exceed')
    ap.add_argument('--gallery', type=int, default=100, help='registered people used to choose the threshold')
    ap.add_argument('--splits', type=int, default=5)
    ap.add_argument('--cache', default=str(Path.home() / 'RaddTest' / '.cache'))
    ap.add_argument('--out', default=str(Path.home() / 'RaddTest' / 'results'))
    args = ap.parse_args()

    photos = [p for p in Path(args.utk).expanduser().rglob('*') if p.suffix.lower() in ('.jpg', '.jpeg', '.png')
              and AGE.match(p.name)]
    rng = random.Random(0)
    by_band = {}
    for name, lo, hi in SUB_BANDS:
        items = sorted(p for p in photos if lo <= int(AGE.match(p.name).group(1)) <= hi)
        rng.shuffle(items)
        by_band[name] = items[:args.per_band]
    paths = sorted({p for items in by_band.values() for p in items})
    engine = radd_engines.make_engine(args.engine)
    engine.warm_up()
    vectors = embed_all(engine, paths, Cache(args.cache, f'utk_{args.engine}'))

    lines = [f'UTKFace held-out check of the age rules ({args.engine}) -- {datetime.now():%Y-%m-%d %H:%M}',
             f'Duplicates >= {args.dup} removed within each age group before splitting. Threshold chosen on the '
             f'calibration half: lowest value (0.01 steps) with wrong person shown <= {args.target}% at N={args.gallery}. '
             f'All results below are on the TEST half only. {args.splits} random splits x 2 directions = '
             f'{2 * args.splits} runs: mean [min-max]; first run with Wilson 95% CI.', '']
    summary = []
    for band, _, _ in SUB_BANDS:
        mat = np.asarray([vectors[p] for p in by_band[band] if vectors[p] is not None], np.float32)
        mat, _, removed = dedupe(mat, args.dup)
        app = APP_RULES[band]
        if len(mat) // 2 <= args.gallery + 1:
            lines += [f'[{band}] only {len(mat)} photos after removing duplicates: too few for halves', '']
            continue
        chosen, app_rates, chosen_rates, first = [], {n: [] for n in GALLERIES}, {n: [] for n in GALLERIES}, {}
        for split in range(args.splits):
            order = np.random.default_rng(100 + split).permutation(len(mat))
            halves = (mat[order[:len(mat) // 2]], mat[order[len(mat) // 2:]])
            for direction in (0, 1):
                cal, test = halves[direction], halves[1 - direction]
                c1, _ = impostor_searches(cal, args.gallery, seed=1000 + split)
                rates = np.array([(c1 >= t).mean() * 100 for t in GRID])
                ok = np.nonzero(rates <= args.target)[0]
                t_chosen = float(GRID[ok[0]]) if len(ok) else float(GRID[-1])
                chosen.append(t_chosen)
                rule_chosen = (t_chosen, app[1], app[2])
                for n in GALLERIES:
                    t1, t2 = impostor_searches(test, n, seed=2000 + split)
                    if t1 is None:
                        continue
                    a = shown(app, t1, t2)
                    c = shown(rule_chosen, t1, t2)
                    app_rates[n].append(100 * a.mean())
                    chosen_rates[n].append(100 * c.mean())
                    if split == 0 and direction == 0:
                        first[n] = (int(a.sum()), len(a), int(c.sum()))

        def fmt(vals):
            return f'{np.mean(vals):4.1f}% [{min(vals):.1f}-{max(vals):.1f}]' if vals else 'n/a'

        rule_text = f'{app[0]:.2f}' + (f', or >= {app[1]:.2f} and {app[2]:.2f} ahead' if app[1] is not None else '')
        lines.append(f'[{band}] photos used {len(mat)} (duplicates removed: {removed}); each half about {len(mat) // 2}')
        lines.append(f'  app rule ({rule_text}): wrong person shown, test halves')
        for n in GALLERIES:
            h, s, _ = first.get(n, (0, 0, 0))
            lo, hi = wilson(h, s) if s else (0, 0)
            lines.append(f'    N={n:<3} {fmt(app_rates[n])}   first run {100 * h / max(s, 1):.1f}% '
                         f'[CI {100 * lo:.1f}-{100 * hi:.1f}]')
        lines.append(f'  threshold chosen on the calibration half: mean {np.mean(chosen):.2f} '
                     f'[{min(chosen):.2f}-{max(chosen):.2f}]  (app: {app[0]:.2f})')
        lines.append('  same rule with the chosen threshold: wrong person shown, test halves: '
                     + '; '.join(f'N={n} {fmt(chosen_rates[n])}' for n in GALLERIES))
        lines.append('')
        summary.append((band, app[0], np.mean(chosen), min(chosen), max(chosen),
                        np.mean(app_rates[100]) if app_rates[100] else float('nan'),
                        np.mean(chosen_rates[100]) if chosen_rates[100] else float('nan')))

    lines.append(f'SUMMARY (test halves, N=100):')
    lines.append('  age group    | app threshold | chosen on calibration half | app rule wrong shown | chosen rule wrong shown')
    for band, t_app, t_mean, t_lo, t_hi, a100, c100 in summary:
        lines.append(f'  {band:12} | {t_app:13.2f} | {t_mean:.2f} [{t_lo:.2f}-{t_hi:.2f}]        | '
                     f'{a100:19.1f}% | {c100:22.1f}%')
    text = '\n'.join(lines)
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    (out / f'utkface_holdout_target{args.target:g}.txt').write_text(text + '\n')
    log('\n' + text)
    log(f'\nSaved {out / f"utkface_holdout_target{args.target:g}.txt"}')


if __name__ == '__main__':
    main()
