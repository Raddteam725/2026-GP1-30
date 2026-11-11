"""Follow-up to radd_utkface_false_match.py: WHERE do the false matches among children come
from, and which threshold keeps them low?

- Finer age bands: 0-2, 3-5, 6-12 (children), 13-17, 18-59, 60+.
- Near-duplicates: UTKFace has no identity labels, so a pair of photos with a very high
  score (>= --dup, default 0.80) is probably the same person or the same picture. These pairs
  are counted, and one photo of each pair is removed before measuring false alarms.
- For a list of thresholds: the share of searches where a WRONG person passes the threshold,
  searching each photo against N random other photos of the same age band (N = 10, 50, 100).

This is a diagnostic: thresholds read from this table should be confirmed on separate data
(same-day phone photos). Uses cached embeddings where available.

Usage (from the repository folder; ai/data is never committed):
  python ai/scripts/radd_utkface_diagnose.py --utk ai/data/utkface
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

SUB_BANDS = [('child 0-2', 0, 2), ('child 3-5', 3, 5), ('child 6-12', 6, 12), ('teen 13-17', 13, 17),
             ('adult 18-59', 18, 59), ('senior 60+', 60, 200)]
AGE = re.compile(r'^(\d+)_')
THRESHOLDS = {'arcface': [0.30, 0.34, 0.38, 0.42, 0.46, 0.50, 0.55, 0.60, 0.65],
              'arcface100': [0.30, 0.34, 0.38, 0.42, 0.46, 0.50, 0.55, 0.60, 0.65],
              'facenet512': [0.596, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90]}
GALLERIES = [10, 50, 100]


def log(text=''):
    print(text, flush=True)


def dedupe(mat, dup):
    sim = mat @ mat.T
    np.fill_diagonal(sim, -1)
    keep = np.ones(len(mat), bool)
    pairs = int((np.triu(sim, 1) >= dup).sum())
    for i in range(len(mat)):
        if keep[i]:
            keep[(sim[i] >= dup) & keep & (np.arange(len(mat)) > i)] = False
    return mat[keep], pairs, int((~keep).sum())


def fpir(mat, t, n, seed, probes=1500):
    rng = random.Random(seed)
    m = len(mat)
    if m <= n:
        return None, 0
    idx = rng.sample(range(m), min(probes, m))
    hits = 0
    for i in idx:
        others = [j for j in rng.sample(range(m), n + 1) if j != i][:n]
        hits += bool((mat[others] @ mat[i] >= t).any())
    return hits, len(idx)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--utk', required=True)
    ap.add_argument('--engines', nargs='+', default=['arcface'])
    ap.add_argument('--arcface-model', default=None)
    ap.add_argument('--per-band', type=int, default=1500)
    ap.add_argument('--dup', type=float, default=0.80, help='score treated as a probable duplicate/same person')
    ap.add_argument('--show-dups', type=int, default=0, help='print the file names of the N highest-scoring pairs '
                                                             'per age band, to check them by eye')
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

    report = [f'UTKFace false-match diagnosis -- {datetime.now():%Y-%m-%d %H:%M}',
              f'Probable duplicates: pairs scoring >= {args.dup}; one photo of each removed before measuring.',
              'Cells: share of searches where a WRONG person passes the threshold, with N people registered '
              '[95% CI].']
    for engine_name in args.engines:
        log(f'\nEngine {engine_name}: loading...')
        engine = radd_engines.make_engine(engine_name, args.arcface_model)
        engine.warm_up()
        vectors = embed_all(engine, paths, Cache(args.cache, f'utk_{engine_name}'))
        report += ['', f'===== {engine_name} =====']
        for name, _, _ in SUB_BANDS:
            kept = [p for p in by_band[name] if vectors[p] is not None]
            mat = np.asarray([vectors[p] for p in kept], np.float32)
            if args.show_dups and len(mat) > 1:
                sim = np.triu(mat @ mat.T, 1)
                top = np.dstack(np.unravel_index(np.argsort(sim, axis=None)[::-1][:args.show_dups], sim.shape))[0]
                log(f'\n[{name}] highest-scoring pairs (open them to check):')
                for i, j in top:
                    log(f'  {sim[i, j]:.3f}  {kept[i].name}  {kept[j].name}')
            if len(mat) < 60:
                report.append(f'\n[{name}] too few photos ({len(mat)})')
                continue
            clean, dup_pairs, removed = dedupe(mat, args.dup)
            report.append(f'\n[{name}] photos {len(mat)}; probable duplicate pairs {dup_pairs} '
                          f'(removed {removed} photos); used {len(clean)}')
            report.append('  threshold | ' + ' | '.join(f'N={n:<3}' + ' ' * 14 for n in GALLERIES))
            for t in THRESHOLDS.get(engine_name, THRESHOLDS['arcface']):
                cells = []
                for n in GALLERIES:
                    hits, used = fpir(clean, t, n, seed=7)
                    if hits is None:
                        cells.append('n/a'.ljust(19))
                        continue
                    lo, hi = wilson(hits, used)
                    cells.append(f'{100 * hits / used:5.1f}% [{100 * lo:.1f}-{100 * hi:.1f}]'.ljust(19))
                report.append(f'  {t:9.3f} | ' + ' | '.join(cells))
    text = '\n'.join(report)
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    (out / 'utkface_diagnosis.txt').write_text(text + '\n')
    log('\n' + text)
    log(f'\nSaved {out / "utkface_diagnosis.txt"}')


if __name__ == '__main__':
    main()
