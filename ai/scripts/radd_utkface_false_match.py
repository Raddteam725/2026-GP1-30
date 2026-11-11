"""False matches by age band on UTKFace (no identity labels): how often does a WRONG person
pass the search threshold, especially among children?

UTKFace has no identity labels, so it cannot measure whether the right person is found.
Every photo is treated as a different person (if a few photos show the same person, false
alarms look slightly worse, so the estimate is conservative). Ages are estimated labels.

For each age band (child 0-12, teen 13-17, adult 18-59, senior 60+):
- photos are split at random into a calibration half and a test half;
- the threshold for a target false-alarm rate (1% / 5%) with a gallery of N people is chosen
  on the calibration half, then checked on the test half;
- the proposed thresholds (--check, e.g. ArcFace 0.30 adults / 0.38 children) are tested
  directly: each test photo is searched against N other test photos of the same band, and
  we count searches where anyone passes the threshold (FPIR, with a 95% CI).

Usage (from the repository folder; ai/data is never committed):
  python ai/scripts/radd_utkface_false_match.py --utk ai/data/utkface
  python ai/scripts/radd_utkface_false_match.py --utk ... --engines arcface facenet512
Only embeddings are cached (~/RaddTest/.cache); no photos are copied.
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
from radd_model_compare import Cache, embed_all, wilson, threshold_for, fmr_at, fpir_from_fmr  # noqa: E402

BANDS = [('child 0-12', 0, 12), ('teen 13-17', 13, 17), ('adult 18-59', 18, 59), ('senior 60+', 60, 200)]
AGE = re.compile(r'^(\d+)_')
TARGETS, GALLERIES = [0.01, 0.05], [10, 100, 300]
DEFAULT_CHECK = {'arcface': {'child 0-12': 0.38, 'teen 13-17': 0.38, 'adult 18-59': 0.30, 'senior 60+': 0.30},
                 'arcface100': {'child 0-12': 0.40, 'teen 13-17': 0.40, 'adult 18-59': 0.31, 'senior 60+': 0.31},
                 'facenet512': {b: 0.596 for b, _, _ in BANDS}}


def log(text=''):
    print(text, flush=True)


def direct_fpir(mat, t, n, rng, probes=2000):
    """Each probe searched against n random OTHER photos; share of searches with a score >= t."""
    m = len(mat)
    if m <= n:
        return None, 0
    idx = rng.sample(range(m), min(probes, m))
    hits = 0
    for i in idx:
        others = [j for j in rng.sample(range(m), n + 1) if j != i][:n]
        hits += bool((mat[others] @ mat[i] >= t).any())
    return hits / len(idx), len(idx)


def pairs(mat):
    sim = mat @ mat.T
    return sim[np.triu_indices(len(mat), 1)].astype(float)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--utk', required=True, help='UTKFace folder (aligned & cropped or in-the-wild)')
    ap.add_argument('--engines', nargs='+', default=['arcface'])
    ap.add_argument('--arcface-model', default=None)
    ap.add_argument('--per-band', type=int, default=1500, help='max photos per age band (default 1500)')
    ap.add_argument('--cache', default=str(Path.home() / 'RaddTest' / '.cache'))
    ap.add_argument('--out', default=str(Path.home() / 'RaddTest' / 'results'))
    args = ap.parse_args()

    photos = [p for p in Path(args.utk).expanduser().rglob('*') if p.suffix.lower() in ('.jpg', '.jpeg', '.png')
              and AGE.match(p.name)]
    if not photos:
        raise SystemExit(f'No UTKFace photos (named <age>_...) found in {args.utk}')
    rng = random.Random(0)
    by_band = {}
    for name, lo, hi in BANDS:
        items = sorted(p for p in photos if lo <= int(AGE.match(p.name).group(1)) <= hi)
        rng.shuffle(items)
        by_band[name] = items[:args.per_band]
    log('UTKFace photos per band (used / available):')
    for name, lo, hi in BANDS:
        avail = sum(lo <= int(AGE.match(p.name).group(1)) <= hi for p in photos)
        log(f'  {name:12} {len(by_band[name]):5} / {avail}')
    paths = sorted({p for items in by_band.values() for p in items})

    report = [f'UTKFace false-match test -- {datetime.now():%Y-%m-%d %H:%M}',
              'Every photo treated as a different person; thresholds chosen on a calibration half, '
              'reported on the test half.']
    for engine_name in args.engines:
        log(f'\nEngine {engine_name}: loading...')
        engine = radd_engines.make_engine(engine_name, args.arcface_model)
        engine.warm_up()
        vectors = embed_all(engine, paths, Cache(args.cache, f'utk_{engine_name}'))
        report += ['', f'===== {engine_name} =====']
        check = DEFAULT_CHECK.get(engine_name, {})
        for name, _, _ in BANDS:
            vecs = [vectors[p] for p in by_band[name] if vectors[p] is not None]
            detected = len(vecs) / max(1, len(by_band[name]))
            rng_b = random.Random(1)
            rng_b.shuffle(vecs)
            half = len(vecs) // 2
            cal, test = np.asarray(vecs[:half], np.float32), np.asarray(vecs[half:], np.float32)
            if len(cal) < 20 or len(test) < 20:
                report.append(f'\n[{name}] not enough photos')
                continue
            cal_imp, test_imp = pairs(cal), pairs(test)
            report.append(f'\n[{name}] photos with a face: {len(vecs)} ({100 * detected:.1f}%), '
                          f'different-person pairs cal/test {len(cal_imp)}/{len(test_imp)}')
            report.append('  target FPIR | N   | threshold (calibration) | test FPIR direct [95% CI]')
            for target in TARGETS:
                for n in GALLERIES:
                    fmr = 1 - (1 - target) ** (1 / n)
                    t = threshold_for(cal_imp.tolist(), fmr)
                    f, used = direct_fpir(test, t, n, random.Random(2))
                    if f is None:
                        report.append(f'  {100 * target:9.0f}%  | {n:<3} | {t:23.3f} | n/a (gallery too large)')
                        continue
                    lo, hi = wilson(round(f * used), used)
                    flag = '' if fmr * len(cal_imp) >= 5 else '  (few impostors: indicative)'
                    report.append(f'  {100 * target:9.0f}%  | {n:<3} | {t:23.3f} | {100 * f:5.1f}% '
                                  f'[{100 * lo:.1f}-{100 * hi:.1f}%] ({used} searches){flag}')
            if name in check:
                t = check[name]
                cells = []
                for n in GALLERIES:
                    f, used = direct_fpir(test, t, n, random.Random(3))
                    if f is None:
                        cells.append(f'N={n}: n/a')
                        continue
                    lo, hi = wilson(round(f * used), used)
                    cells.append(f'N={n}: {100 * f:.1f}% [{100 * lo:.1f}-{100 * hi:.1f}]')
                report.append(f'  proposed threshold {t}: wrong person shown in ' + '; '.join(cells))
                report.append(f'    (per-comparison false match rate {100 * fmr_at(test_imp.tolist(), t):.3f}%, '
                              f'estimated N=100: {100 * fpir_from_fmr(fmr_at(test_imp.tolist(), t), 100):.1f}%)')
    text = '\n'.join(report)
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    (out / 'utkface_summary.txt').write_text(text + '\n')
    log('\n' + text)
    log(f'\nSaved {out / "utkface_summary.txt"}')


if __name__ == '__main__':
    main()
