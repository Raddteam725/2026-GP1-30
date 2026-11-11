"""Radd model comparison and threshold calibration by age band.

Compares face-recognition engines (current Facenet512 vs ArcFace R50) on AgeDB and LFW,
separately for each age band, and derives a threshold per band from a target false-alarm
rate. Thresholds are chosen on one half of the identities (calibration) and reported on
the other half (test), so the reported numbers are not tuned on the same people.

Definitions (open-set 1:N identification, as in NIST FRVT):
  FPIR  false positive identification rate: a found person who is NOT registered still gets
        a candidate above the threshold (a wrong child is shown).
  FNIR  false negative identification rate: a registered person's own photo scores below
        the threshold (the right child is not shown).
  For a gallery of N registered people, FPIR is estimated from the per-comparison false match
  rate FMR as FPIR = 1 - (1 - FMR)^N, and checked directly by simulation where enough
  identities exist.

Trials, per age band (age at the photo): child 0-12, teen 13-17, adult 18-59, senior 60+ (AgeDB)
and lfw (LFW adults, age unknown). Genuine pair = two photos of one person at most --max-gap
years apart in the same band (LFW: two photos of one person). Impostors = found photos
every pair of photos of two DIFFERENT people in the same band (the hard case: a child compared
with other children); the direct check searches found photos against other people's
registration photos.

Usage (from the repository folder; ai/data is never committed):
  python ai/scripts/radd_model_compare.py --data ai/data
  python ai/scripts/radd_model_compare.py --data ... --engines facenet512 arcface
Nothing is copied; only embeddings of AgeDB/LFW photos are cached (in --cache).
"""
import argparse
import collections
import hashlib
import json
import math
import random
import re
import sys
import time
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import radd_engines  # noqa: E402

AGEDB_NAME = re.compile(r'^(\d+)_(.+)_(\d+)_([mf])\.jpg$', re.IGNORECASE)
BANDS = ['child', 'teen', 'adult', 'senior', 'lfw']
BAND_LABEL = {'child': 'child 0-12', 'teen': 'teen 13-17', 'adult': 'adult 18-59', 'senior': 'senior 60+',
              'lfw': 'LFW adults'}
TARGETS = [0.01, 0.05]          # FPIR targets
GALLERIES = [10, 100]           # registered people searched
CURRENT = 0.596


def log(text=''):
    print(text, flush=True)


def band_of(age):
    return 'child' if age <= 12 else 'teen' if age <= 17 else 'adult' if age <= 59 else 'senior'


def split_of(name):
    return 'calibration' if int(hashlib.sha1(name.encode()).hexdigest(), 16) % 2 == 0 else 'test'


def wilson(k, n):
    if n == 0:
        return (0.0, 0.0)
    z, p = 1.96, k / n
    centre = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return max(0.0, centre - half), min(1.0, centre + half)


# ------------------------------------------------------------------ trials

def pick_registration(photos, max_gap, per_id):
    """photos: [(age, path)] sorted by age. Registration = the earliest photo that has another
    photo at most max_gap years later; found = up to per_id such photos (closest first)."""
    for i, (age, path) in enumerate(photos):
        later = sorted(((b_age - age, b_path) for b_age, b_path in photos[i + 1:] if b_age - age <= max_gap),
                       key=lambda x: (x[0], x[1].name))
        if later:
            return path, [(p, gap) for gap, p in later[:per_id]]
    return photos[0][1], []


def build_trials(data, args):
    """Returns {band: [identity]}; identity = dict(name, split, registration, found=[(path, gap)])."""
    rng = random.Random(0)
    by_band = collections.defaultdict(list)
    agedb = data / 'agedb'
    if agedb.is_dir():
        people = collections.defaultdict(list)
        for p in agedb.rglob('*.jpg'):
            m = AGEDB_NAME.match(p.name)
            if m:
                people[m.group(2)].append((int(m.group(3)), p))
        for name, photos in sorted(people.items()):
            groups = collections.defaultdict(list)
            for age, p in photos:
                groups[band_of(age)].append((age, p))
            for band, items in groups.items():
                items.sort(key=lambda x: (x[0], x[1].name))
                registration, found = pick_registration(items, args.max_gap, args.pairs_per_id)
                chosen = {registration} | {p for p, _ in found}
                photos = [registration] + [p for p, _ in found] + [p for _, p in items if p not in chosen]
                by_band[band].append(dict(name=f'agedb:{name}', split=split_of(name), registration=registration,
                                          found=found, photos=photos[:args.photos_per_id]))
    else:
        log(f'note: AgeDB not found at {agedb}')
    lfw = data / 'lfw'
    if lfw.is_dir():
        folders = collections.defaultdict(list)
        for p in sorted(lfw.rglob('*.jpg')):
            folders[p.parent.name].append(p)
        for name, photos in sorted(folders.items()):
            by_band['lfw'].append(dict(name=f'lfw:{name}', split=split_of(name), registration=photos[0],
                                       found=[(p, 0) for p in photos[1:1 + args.pairs_per_id]],
                                       photos=photos[:args.photos_per_id]))
    else:
        log(f'note: LFW not found at {lfw}')
    for band in list(by_band):
        ids = by_band[band]
        with_pairs = [i for i in ids if i['found']]
        without = [i for i in ids if not i['found']]
        rng.shuffle(with_pairs)
        rng.shuffle(without)
        keep = with_pairs[:args.max_ids]
        keep += without[:max(0, args.max_ids - len(keep))]
        by_band[band] = keep
    return by_band


# ------------------------------------------------------------------ embeddings

class Cache:
    def __init__(self, folder, engine_name):
        self.file = Path(folder).expanduser() / f'compare_{engine_name}.json'
        self.data = json.loads(self.file.read_text()) if self.file.exists() else {}
        self.dirty = 0

    @staticmethod
    def key(path):
        st = path.stat()
        return f'{path.resolve()}|{st.st_size}|{st.st_mtime_ns}'

    def get(self, path):
        return self.data.get(self.key(path), 'missing')

    def put(self, path, vector):
        self.data[self.key(path)] = vector
        self.dirty += 1
        if self.dirty >= 100:
            self.save()

    def save(self):
        if self.dirty:
            self.file.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.file.with_suffix('.tmp')
            tmp.write_text(json.dumps(self.data))
            tmp.replace(self.file)
            self.dirty = 0


def embed_all(engine, paths, cache):
    todo = [p for p in paths if cache.get(p) == 'missing']
    log(f'  {len(paths)} photos, {len(paths) - len(todo)} cached, {len(todo)} to embed')
    started = time.perf_counter()
    for i, p in enumerate(todo, 1):
        cache.put(p, engine.embed(p.read_bytes()))
        if i % 100 == 0 or i == len(todo):
            rate = (time.perf_counter() - started) / i
            log(f'    {i}/{len(todo)}  (~{rate * (len(todo) - i) / 60:.1f} min left)')
    cache.save()
    return {p: cache.get(p) for p in paths}


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


# ------------------------------------------------------------------ scoring

def scores(identities, vectors, split):
    """Genuine scores (registration vs found), per-probe impostor rows (found photo vs other
    people's registrations, for the direct check) and all cross-identity photo-pair scores
    (for the false match rate)."""
    import numpy as np
    ids = [i for i in identities if i['split'] == split]
    gallery = [(i['name'], vectors[i['registration']]) for i in ids if vectors[i['registration']] is not None]
    names = [n for n, _ in gallery]
    gmat = np.asarray([v for _, v in gallery], dtype=np.float32).reshape(len(gallery), -1)
    genuine, rows, probes, no_face = [], [], 0, 0
    for ident in ids:
        registered = ident['name'] in names
        for path, _gap in ident['found']:
            probes += 1
            v = vectors[path]
            if not registered:
                genuine.append(None)  # no face in the registration photo: unreachable by AI (as in the app)
            if v is None:
                no_face += 1
                if registered:
                    genuine.append(None)  # no face in the found photo = the right person is missed
                continue
            sims = gmat @ np.asarray(v, dtype=np.float32) if len(gallery) else np.zeros(0)
            rows.append([float(x) for n, x in zip(names, sims) if n != ident['name']])
            own = [float(x) for n, x in zip(names, sims) if n == ident['name']]
            if own:
                genuine.append(own[0])
    labels, vecs = [], []
    for k, ident in enumerate(ids):
        for p in ident['photos']:
            if vectors[p] is not None:
                labels.append(k)
                vecs.append(vectors[p])
    impostors = []
    if len(vecs) > 1:
        m = np.asarray(vecs, dtype=np.float32)
        lab = np.asarray(labels)
        sim = m @ m.T
        upper = np.triu(np.ones_like(sim, dtype=bool), 1) & (lab[:, None] != lab[None, :])
        impostors = sim[upper].astype(float).tolist()
    return dict(genuine=genuine, rows=rows, impostors=impostors, probes=probes, no_face=no_face, ids=len(ids))


def threshold_for(impostors, fmr):
    """Smallest threshold whose empirical FMR on these impostor scores is <= fmr."""
    if not impostors:
        return None
    s = sorted(impostors, reverse=True)
    k = int(math.floor(fmr * len(s)))          # number of impostors allowed above the threshold
    return (s[k] + 1e-6) if k < len(s) else s[-1]


def fmr_at(impostors, t):
    return sum(x >= t for x in impostors) / len(impostors) if impostors else 0.0


def fpir_from_fmr(fmr, n):
    return 1 - (1 - fmr) ** n


def direct_fpir(rows, t, n, seed=0):
    """Simulated open-set searches: each probe against n random other people."""
    rng = random.Random(seed)
    usable = [r for r in rows if len(r) >= n]
    if not usable:
        return None, 0
    hits = sum(max(rng.sample(r, n)) >= t for r in usable)
    return hits / len(usable), len(usable)


def fnir_at(genuine, t):
    misses = sum(g is None or g < t for g in genuine)
    return misses, len(genuine)


def pct(x):
    return '  n/a' if x is None else f'{100 * x:5.1f}%'


# ------------------------------------------------------------------ report

def analyse(engine_name, trials, vectors):
    lines, table = [f'===== {engine_name} ====='], {}
    for band in BANDS:
        if band not in trials:
            continue
        cal, test = scores(trials[band], vectors, 'calibration'), scores(trials[band], vectors, 'test')
        cal_imp, test_imp = cal['impostors'], test['impostors']
        det = 1 - (cal['no_face'] + test['no_face']) / max(1, cal['probes'] + test['probes'])
        lines += ['', f'[{BAND_LABEL[band]}]  identities cal/test {cal["ids"]}/{test["ids"]}, '
                      f'genuine pairs {len(cal["genuine"])}/{len(test["genuine"])}, '
                      f'different-person photo pairs {len(cal_imp)}/{len(test_imp)}, face detected {100 * det:.1f}%']
        if not test['genuine'] or not cal_imp or not test_imp:
            lines.append('  not enough data in this band')
            continue
        m, n = fnir_at(test['genuine'], CURRENT)
        lo, hi = wilson(m, n)
        lines.append(f'  current threshold {CURRENT}: FNIR {pct(m / n)} [CI {100 * lo:.0f}-{100 * hi:.0f}%], '
                     f'FPIR est. N=10 {pct(fpir_from_fmr(fmr_at(test_imp, CURRENT), 10))}, '
                     f'N=100 {pct(fpir_from_fmr(fmr_at(test_imp, CURRENT), 100))}')
        lines.append('  target FPIR | gallery N | threshold (calibration) | test FPIR est. | test FPIR direct | '
                     'test FNIR [95% CI]')
        for target in TARGETS:
            for gallery_n in GALLERIES:
                fmr = 1 - (1 - target) ** (1 / gallery_n)
                t = threshold_for(cal_imp, fmr)
                reliable = fmr * len(cal_imp) >= 5
                est = fpir_from_fmr(fmr_at(test_imp, t), gallery_n)
                direct, used = direct_fpir(test['rows'], t, gallery_n)
                m, n = fnir_at(test['genuine'], t)
                lo, hi = wilson(m, n)
                flag = '' if reliable else '  (too few impostors: unreliable)'
                direct_text = f'{pct(direct)} ({used})' if direct is not None else '   n/a'
                lines.append(f'  {100 * target:9.0f}%  | {gallery_n:9} | {t:23.3f} | {pct(est):>14} | '
                             f'{direct_text:>16} | {pct(m / n)} [{100 * lo:.0f}-{100 * hi:.0f}%]{flag}')
                table[(band, target, gallery_n)] = dict(threshold=round(t, 4), fnir=m / n, fpir_est=est,
                                                        reliable=reliable)
    return lines, table


def comparison(tables):
    if len(tables) < 2:
        return []
    names = list(tables)
    lines = ['', '===== side by side: FNIR (right person missed) at the SAME false-alarm target =====',
             '  band        | target | N   | ' + ' | '.join(f'{n:>22}' for n in names)]
    for band in BANDS:
        for target in TARGETS:
            for gallery_n in GALLERIES:
                cells = []
                for n in names:
                    r = tables[n].get((band, target, gallery_n))
                    cells.append('—' if r is None else f't={r["threshold"]:.3f} FNIR {100 * r["fnir"]:4.1f}%'
                                 + ('' if r['reliable'] else '*'))
                if any(c != '—' for c in cells):
                    lines.append(f'  {BAND_LABEL[band]:11} | {100 * target:4.0f}%  | {gallery_n:<3} | '
                                 + ' | '.join(f'{c:>22}' for c in cells))
    lines.append('  * too few impostor comparisons for this target; treat as indicative.')
    return lines


def main():
    ap = argparse.ArgumentParser(description='Compare engines and calibrate thresholds by age band.')
    ap.add_argument('--data', required=True, help='folder containing agedb/ and lfw/')
    ap.add_argument('--engines', nargs='+', default=['facenet512', 'arcface'])
    ap.add_argument('--arcface-model', default=str(Path.home() / 'RaddModels' / 'w600k_r50.onnx'))
    ap.add_argument('--max-gap', type=int, default=3, help='max years between the two photos of a pair')
    ap.add_argument('--pairs-per-id', type=int, default=2, help='max found photos per identity')
    ap.add_argument('--photos-per-id', type=int, default=6,
                    help='max photos per identity used for the false-match statistics')
    ap.add_argument('--max-ids', type=int, default=200, help='max identities per band (children: all are kept '
                                                             'if fewer)')
    ap.add_argument('--cache', default=str(Path.home() / 'RaddTest' / '.cache'))
    ap.add_argument('--out', default=str(Path.home() / 'RaddTest' / 'results'))
    args = ap.parse_args()

    data = Path(args.data).expanduser().resolve()
    trials = build_trials(data, args)
    paths = sorted({p for ids in trials.values() for i in ids for p in i['photos']})
    log('Test set:')
    for band in BANDS:
        if band in trials:
            ids = trials[band]
            log(f'  {BAND_LABEL[band]:12} identities {len(ids):4}, with a genuine pair {sum(bool(i["found"]) for i in ids):4}, '
                f'found photos {sum(len(i["found"]) for i in ids):4}')
    log(f'  photos to use: {len(paths)}')

    report, tables = [f'Radd model comparison -- {datetime.now():%Y-%m-%d %H:%M}',
                      f'max gap {args.max_gap}y, pairs per identity {args.pairs_per_id}, max identities per band '
                      f'{args.max_ids}; thresholds chosen on calibration identities, reported on test identities.'], {}
    for name in args.engines:
        log(f'\nEngine {name}: loading...')
        engine = radd_engines.make_engine(name, args.arcface_model)
        engine.warm_up()
        vectors = embed_all(engine, paths, Cache(args.cache, name))
        lines, tables[name] = analyse(name, trials, vectors)
        report += [''] + lines
    report += comparison(tables)
    text = '\n'.join(report)
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    (out / 'compare_summary.txt').write_text(text + '\n')
    thresholds = {name: {f'{b}|{t}|{n}': r for (b, t, n), r in tab.items()} for name, tab in tables.items()}
    (out / 'compare_thresholds.json').write_text(json.dumps(thresholds, indent=1))
    log('\n' + text)
    log(f'\nSaved {out / "compare_summary.txt"} and {out / "compare_thresholds.json"}')


if __name__ == '__main__':
    main()
