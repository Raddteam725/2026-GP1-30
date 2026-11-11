"""Test smarter "show a candidate" rules than one fixed threshold (C7, ArcFace).

Rules compared, per age group:
  T          threshold only: show the top candidate if its score >= the age group's threshold.
  T|M(f,g)   threshold OR clear winner: also show it if score >= f AND it beats the
             second-best candidate by at least g.
  Z(z)       gallery-normalised score: (top score - mean of the other gallery scores) / their
             standard deviation >= z ("how far the winner stands out from this gallery").

False alarms (UTKFace, no identity labels): each photo is searched against N random OTHER photos
of the same age group (probable duplicates >= 0.80 removed, as in radd_utkface_diagnose.py);
FPIR = share of searches where the rule shows someone.

Right person shown (same-day field tests): the known same-day similarity of each photo (kid1 aged 9,
kid2 aged 3) is placed into the same simulated galleries, i.e. we ASSUME the child's similarity to
other children of that age looks like a typical UTKFace photo's. A search counts as correct if the
child is the top candidate and the rule shows it. Field-test embeddings were not kept (privacy), so
this transplant is an approximation; with one child per age it is indicative only.

Usage (from the repository folder; uses the cached UTKFace embeddings):
  python ai/scripts/radd_margin_test.py --utk ai/data/utkface
"""
import argparse
import random
import re
import sys
from datetime import datetime
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import radd_engines  # noqa: E402
from radd_model_compare import Cache, embed_all, wilson  # noqa: E402
from radd_utkface_diagnose import SUB_BANDS, AGE, dedupe  # noqa: E402

BASE_T = {'child 0-2': 0.65, 'child 3-5': 0.60, 'child 6-12': 0.38, 'teen 13-17': 0.38,
          'adult 18-59': 0.30, 'senior 60+': 0.38}
# Same-day field-test similarities (photo -> registration), ArcFace, 9 Nov 2026.
GENUINE = {'child 6-12': ('kid1 (9y)', [0.889, 0.832, 0.826, 0.824, 0.780, 0.617, 0.537]),
           'child 3-5': ('kid2 (3y)', [0.640, 0.588, 0.566, 0.491])}
FLOORS, GAPS, ZS = [0.35, 0.40, 0.45], [0.10, 0.15, 0.20, 0.25], [3.0, 4.0, 5.0, 6.0]
GALLERIES = [10, 50, 100]


def log(text=''):
    print(text, flush=True)


def rules():
    out = [('T', None)]
    out += [(f'T|M({f:.2f},{g:.2f})', (f, g)) for f in FLOORS for g in GAPS]
    out += [(f'Z({z:g})', z) for z in ZS]
    return out


def shown(rule, t_band, top1, top2, z):
    name, p = rule
    if name == 'T':
        return top1 >= t_band
    if name.startswith('T|M'):
        f, g = p
        return (top1 >= t_band) | ((top1 >= f) & (top1 - top2 >= g))
    return z >= p


def searches(mat, n, seed, probes=1500):
    """Impostor searches: top-1, top-2, and mean/std of the gallery scores without the top-1."""
    rng = random.Random(seed)
    m = len(mat)
    idx = rng.sample(range(m), min(probes, m))
    top1, top2, rest_mean, rest_std, all_mean, all_std = [], [], [], [], [], []
    for i in idx:
        others = [j for j in rng.sample(range(m), n + 1) if j != i][:n]
        s = np.sort(mat[others] @ mat[i])[::-1]
        top1.append(s[0])
        top2.append(s[1])
        rest_mean.append(s[1:].mean())
        rest_std.append(s[1:].std() + 1e-6)
        all_mean.append(s.mean())
        all_std.append(s.std() + 1e-6)
    return tuple(np.array(x) for x in (top1, top2, rest_mean, rest_std, all_mean, all_std))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--utk', required=True)
    ap.add_argument('--engine', default='arcface')
    ap.add_argument('--per-band', type=int, default=1500)
    ap.add_argument('--dup', type=float, default=0.80)
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

    all_rules = rules()
    fpir = {}      # (rule, band, n) -> (hits, searches)
    genuine = {}   # (rule, band, n) -> share of correct shows over photos x simulated galleries
    for band, _, _ in SUB_BANDS:
        mat = np.asarray([vectors[p] for p in by_band[band] if vectors[p] is not None], np.float32)
        mat, _, _ = dedupe(mat, args.dup)
        t_band = BASE_T[band]
        for n in GALLERIES:
            top1, top2, mu, sd, all_mu, all_sd = searches(mat, n, seed=11)
            z_imp = (top1 - mu) / sd
            for rule in all_rules:
                hits = int(shown(rule, t_band, top1, top2, z_imp).sum())
                fpir[(rule[0], band, n)] = (hits, len(top1))
            if band in GENUINE:
                # genuine score g joins a gallery of n-1 wrong people: reuse the impostor searches
                # (their top-1/top-2/rest statistics describe the wrong people in the gallery)
                for rule in all_rules:
                    ok = 0
                    total = 0
                    for g in GENUINE[band][1]:
                        is_top = g > top1
                        t1 = np.where(is_top, g, top1)
                        t2 = top1  # used only where the child is the top candidate
                        # z of the genuine score against ALL the wrong people's scores
                        z = (g - all_mu) / all_sd
                        ok += int((is_top & shown(rule, t_band, t1, t2, z)).sum())
                        total += len(top1)
                    genuine[(rule[0], band, n)] = ok / total

    lines = [f'Radd "show a candidate" rule test ({args.engine}) -- {datetime.now():%Y-%m-%d %H:%M}',
             'Wrong person shown (UTKFace, duplicates >= %.2f removed) and right child shown (field-test scores '
             'transplanted into the same galleries). Base thresholds: %s' % (
                 args.dup, ', '.join(f'{b} {t}' for b, t in BASE_T.items())), '']
    for band, _, _ in SUB_BANDS:
        lines.append(f'[{band}]  rows: rule | wrong person shown N=10 / 50 / 100'
                     + (f' | {GENUINE[band][0]} shown N=10 / 50 / 100' if band in GENUINE else ''))
        for rule in all_rules:
            cells = []
            for n in GALLERIES:
                h, s = fpir[(rule[0], band, n)]
                cells.append(f'{100 * h / s:5.1f}%')
            row = f'  {rule[0]:16} | ' + ' / '.join(cells)
            if band in GENUINE:
                row += ' | ' + ' / '.join(f'{100 * genuine[(rule[0], band, n)]:5.1f}%' for n in GALLERIES)
            lines.append(row)
        lines.append('')

    lines.append('SUMMARY at N=100: worst wrong-person rate over all age groups, and right child shown')
    lines.append(f'  {"rule":16} | worst wrong (group)          | kid2 3y | kid1 9y')
    for rule in all_rules:
        worst = max(((100 * fpir[(rule[0], b, 100)][0] / fpir[(rule[0], b, 100)][1], b) for b, _, _ in SUB_BANDS))
        h, s = fpir[(rule[0], worst[1], 100)]
        lo, hi = wilson(h, s)
        lines.append(f'  {rule[0]:16} | {worst[0]:5.1f}% [{100 * lo:.1f}-{100 * hi:.1f}] ({worst[1]:11}) | '
                     f'{100 * genuine[(rule[0], "child 3-5", 100)]:5.1f}%  | {100 * genuine[(rule[0], "child 6-12", 100)]:5.1f}%')
    lines.append('')
    lines.append('Notes: one child per age for the right-person column; the transplant assumes each child '
                 'resembles other children of that age like a typical UTKFace photo. Indicative only.')
    text = '\n'.join(lines)
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    (out / 'margin_rule_test.txt').write_text(text + '\n')
    log('\n' + text)
    log(f'\nSaved {out / "margin_rule_test.txt"}')


if __name__ == '__main__':
    main()
