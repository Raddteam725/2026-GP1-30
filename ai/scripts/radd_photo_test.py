"""Radd photo test: reusable face-matching test for new photos.

Put photos in a test folder (default ~/RaddTest), run this script and get the
results. Run it again whenever you add photos, or start it with --watch and it
re-tests automatically every time the folder changes (the model stays loaded).

Folder layout (use CODE NAMES for folders, e.g. kid1, kid2; never real names):

  ~/RaddTest/people/<code_name>/reg_<age>y.jpg    registration photo (exactly one)
  ~/RaddTest/people/<code_name>/<age>y.jpg        found photos (as many as you like)
  ~/RaddTest/people/<code_name>/<age>y_2.jpg      more found photos at the same age

  Example:  people/kid1/reg_6y.jpg  people/kid1/6y.jpg  people/kid1/6y_2.jpg  people/kid1/8y.jpg
  A folder with no reg_ photo is a person who is NOT registered (tests false alarms).
  <age> is the age in years when the photo was taken; it gives the age gap.
  Photo types: jpg, jpeg, png, webp, heic, heif.

Reference data, read in place from --data (nothing is copied):
  - AgeDB children (age <= 12, two photos <= 3 years apart): the same selection
    as the earlier child test, so its rows can be compared with that run.
  - Extra registered people: other AgeDB children, then LFW adults, until the
    gallery reaches --gallery-size.

Privacy:
  - No photos are copied or uploaded. The results contain code names and numbers only.
  - Embeddings of your own photos are never saved to disk.
  - Only AgeDB/LFW embeddings are cached (<folder>/.cache), so later runs start fast.
  - Delete the whole test folder when you are done.

Usage (from the repository folder; ai/data holds the datasets and is never committed):
  python ai/scripts/radd_photo_test.py --data ai/data
  python ai/scripts/radd_photo_test.py --data ai/data --watch
Options:
  --engine arcface          default: ArcFace R50 (C7, the app's engine); also facenet512 (C6) or
                            arcface100 (see radd_engines.py)
  --threshold 0.30          default 0.30 for ArcFace, 0.596 for Facenet512
  --child-threshold 0.38    stricter threshold for registered people aged <= 17 (app bands 0-5, 6-17);
                            the threshold table then varies the child threshold
"""
import argparse
import collections
import csv
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

IMAGE_TYPES = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'}
AGEDB_NAME = re.compile(r'^(\d+)_(.+)_(\d+)_([mf])\.jpg$', re.IGNORECASE)
AGE_IN_NAME = re.compile(r'(?<!\d)(\d{1,2})y(?![a-z])', re.IGNORECASE)
CHILD_MAX_AGE, MAX_GAP, HOLD_OUT, SEED = 12, 3, 10, 0
# Scores of the two model families are on different scales: never use 0.596 with ArcFace.
DEFAULT_THRESHOLD = {'arcface': 0.30, 'arcface100': 0.30, 'facenet512': 0.596}
KIND_LABELS = {'own': 'one of your people', 'agedb': 'AgeDB test child', 'agedb_child': 'AgeDB child',
               'lfw_adult': 'LFW adult'}
THRESHOLD_TABLES = {'facenet512': [0.55, 0.596, 0.62, 0.64, 0.664, 0.69, 0.72],
                    'arcface': [0.25, 0.30, 0.34, 0.38, 0.45, 0.50, 0.55, 0.60, 0.65]}
THRESHOLD_TABLES['arcface100'] = THRESHOLD_TABLES['arcface']


# ---------------------------------------------------------------- helpers

def log(text=''):
    print(text, flush=True)


def images(folder):
    return sorted(p for p in Path(folder).rglob('*')
                  if p.is_file() and p.suffix.lower() in IMAGE_TYPES and not p.name.startswith('.'))


def file_key(path):
    st = path.stat()
    return f'{path.resolve()}|{st.st_size}|{st.st_mtime_ns}'


def read_bytes(path):
    if path.suffix.lower() in ('.heic', '.heif'):
        try:
            import pillow_heif
            pillow_heif.register_heif_opener()
        except ImportError:
            raise SystemExit(f'{path.name}: HEIC photo. Run "pip install pillow-heif" or convert it to JPG.')
    return path.read_bytes()


def squash(name):
    return re.sub(r'[^a-z]', '', name.lower())


def same_name(a, b):
    a, b = squash(a), squash(b)
    return len(a) >= 5 and len(b) >= 5 and (a.startswith(b) or b.startswith(a))


def age_group(age):
    if age is None:
        return 'age?'
    return 'child' if age <= 12 else 'teen' if age <= 17 else 'adult'


def gap_bucket(gap):
    if gap is None:
        return 'gap?'
    gap = abs(gap)
    return ('gap 0y' if gap == 0 else 'gap 1y' if gap == 1 else 'gap 2-3y' if gap <= 3
            else 'gap 4-9y' if gap <= 9 else 'gap 10y+')


def wilson(k, n):
    """95% Wilson interval, in percent."""
    if n == 0:
        return None
    z, p = 1.96, k / n
    centre = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return max(0, centre - half) * 100, min(1, centre + half) * 100


def rate(k, n, ci=True):
    if n == 0:
        return '0/0'
    text = f'{k}/{n} ({100 * k / n:.0f}%)'
    if ci:
        lo, hi = wilson(k, n)
        text += f'  [95% CI {lo:.0f}-{hi:.0f}%]'
    return text


# ---------------------------------------------------------------- embeddings

class Embedder:
    """Embeds photos once. Reference (AgeDB/LFW) embeddings are cached on disk;
    embeddings of the team's own photos are kept in memory only."""

    def __init__(self, cache_file, engine_name, arcface_model):
        log(f'Loading the {engine_name} model (the first run downloads the weights)...')
        self.engine = radd_engines.make_engine(engine_name, arcface_model)
        self.engine.warm_up()
        log('Model ready.')
        self.cache_file = cache_file
        self.disk = {}
        if cache_file.exists():
            try:
                self.disk = json.loads(cache_file.read_text())
            except ValueError:
                self.disk = {}
        self.memory = {}
        self.new_on_disk = 0

    def embed(self, path, reference):
        key = file_key(path)
        store = self.disk if reference else self.memory
        if key not in store:
            store[key] = self.engine.embed(read_bytes(path))  # None = no face detected
            if reference:
                self.new_on_disk += 1
        return store[key]

    def save(self):
        if self.new_on_disk:
            self.cache_file.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.cache_file.with_suffix('.tmp')
            tmp.write_text(json.dumps(self.disk))
            tmp.replace(self.cache_file)
            self.new_on_disk = 0


# ---------------------------------------------------------------- test set

def own_people(root):
    """Return (people, warnings). person = dict(name, registration, found=[(path, age)], reg_age)."""
    people, warnings = [], []
    base = root / 'people'
    if not base.is_dir():
        return people, warnings
    for folder in sorted(p for p in base.iterdir() if p.is_dir() and not p.name.startswith('.')):
        photos = images(folder)
        regs = [p for p in photos if p.name.lower().startswith('reg')]
        if len(regs) > 1:
            warnings.append(f'{folder.name}: {len(regs)} reg_ photos; using {regs[0].name} only')
        reg = regs[0] if regs else None
        reg_age = age_from_name(reg) if reg else None
        reg_hash = hashlib.sha256(reg.read_bytes()).hexdigest() if reg else None
        found = []
        for p in photos:
            if p in regs:
                continue
            if reg_hash and hashlib.sha256(p.read_bytes()).hexdigest() == reg_hash:
                warnings.append(f'{folder.name}/{p.name}: identical to the registration photo, skipped')
                continue
            age = age_from_name(p)
            if age is None:
                warnings.append(f'{folder.name}/{p.name}: no age in the file name (e.g. 7y.jpg); gap unknown')
            found.append((p, age))
        if reg and reg_age is None:
            warnings.append(f'{folder.name}/{reg.name}: no age in the file name (e.g. reg_7y.jpg); gap unknown')
        people.append(dict(name=folder.name, source='own', registration=reg, reg_age=reg_age, found=found))
    return people, warnings


def age_from_name(path):
    m = AGE_IN_NAME.search(path.stem)
    return int(m.group(1)) if m else None


def agedb_people(agedb):
    """The earlier child-test selection (seed 0), read in place. Returns (people, single_photos)."""
    by_name = collections.defaultdict(list)
    for p in agedb.rglob('*.jpg'):
        m = AGEDB_NAME.match(p.name)
        if m and int(m.group(3)) <= CHILD_MAX_AGE:
            by_name[m.group(2)].append((int(m.group(3)), p))
    pairs, singles = [], []
    for name, photos in sorted(by_name.items()):
        photos.sort(key=lambda x: (x[0], x[1].name))
        best = min(((b[0] - a[0], a, b) for i, a in enumerate(photos) for b in photos[i + 1:]),
                   default=None, key=lambda x: x[0])
        if best and best[0] <= MAX_GAP:
            pairs.append((name, best))
        else:
            singles.append((name, photos[0][1]))
    random.seed(SEED)
    random.shuffle(pairs)
    k = min(HOLD_OUT, len(pairs) // 3)
    people = []
    for i, (name, (gap, a, b)) in enumerate(pairs):
        registered = i >= k
        people.append(dict(name=name, source='agedb', registration=a[1] if registered else None,
                           reg_age=a[0], found=[(b[1], b[0])]))
    return people, singles


def lfw_adults(lfw):
    first = {}
    for p in sorted(lfw.rglob('*.jpg')):
        first.setdefault(p.parent, p)
    return list(first.values())


# ---------------------------------------------------------------- one test run

def run(root, data, args, embedder):
    started = time.perf_counter()
    people, warnings = own_people(root)
    singles, adults = [], []
    if data:
        agedb, lfw = data / 'agedb', data / 'lfw'
        if agedb.is_dir():
            agedb_test, singles = agedb_people(agedb)
            if not args.no_agedb:
                people += agedb_test
        else:
            warnings.append(f'AgeDB not found at {agedb}')
        if lfw.is_dir():
            adults = lfw_adults(lfw)
        else:
            warnings.append(f'LFW not found at {lfw}')
    if not any(p['found'] for p in people):
        log('No found photos yet. Add photos under people/<code_name>/ (see the top of this script).')
        return

    for w in warnings:
        log(f'  note: {w}')

    # Gallery: registered test people, then extra people up to --gallery-size.
    gallery = []  # (label, kind, vector)
    no_face_reg = []
    for person in people:
        if person['registration'] is None:
            continue
        vector = embedder.embed(person['registration'], reference=person['source'] != 'own')
        if vector is None:
            no_face_reg.append(person['name'])
            continue
        gallery.append((person['name'], person['source'], vector, person['reg_age']))
    registered = {g[0] for g in gallery}
    test_names = [p['name'] for p in people]
    need = max(0, args.gallery_size - len(gallery))
    extra = [('agedb_child', p, int(AGEDB_NAME.match(p.name).group(3))) for name, p in singles
             if not any(same_name(name, t) for t in test_names)]
    extra += [('lfw_adult', p, None) for p in adults if not any(same_name(p.parent.name, t) for t in test_names)]
    added, done = collections.Counter(), 0
    for kind, path, extra_age in extra:
        if done >= need:
            break
        vector = embedder.embed(path, reference=True)
        if vector is not None:
            added[kind] += 1
            gallery.append((f'{kind}_{added[kind]:03d}', kind, vector, extra_age))
            done += 1
        if embedder.new_on_disk and embedder.new_on_disk % 50 == 0:
            log(f'  reference photos embedded: {embedder.new_on_disk} (cached for next time)')
            embedder.save()
    embedder.save()
    if no_face_reg:
        log(f'  NO FACE in registration photo (person left out of the gallery): {", ".join(no_face_reg)}')
    log(f'Gallery: {len(gallery)} registered people '
        f'({sum(1 for g in gallery if g[1] == "own")} yours, {sum(1 for g in gallery if g[1] == "agedb")} AgeDB test, '
        f'{added["agedb_child"]} other AgeDB children, {added["lfw_adult"]} LFW adults)')
    if len(gallery) < args.gallery_size:
        log(f'  note: gallery is smaller than --gallery-size {args.gallery_size} (not enough reference photos)')

    # Found photos.
    rows = []
    for person in people:
        for path, age in person['found']:
            vector = embedder.embed(path, reference=person['source'] != 'own')
            is_reg = person['name'] in registered
            gap = None if age is None or person['reg_age'] is None or not is_reg else age - person['reg_age']
            condition = f'{age_group(age)}, {gap_bucket(gap) if is_reg else "not registered"}'
            row = dict(source=person['source'], person=person['name'], photo=path.name, age=age,
                       registered=is_reg, gap_years=gap, condition=condition, face_detected=vector is not None)
            if vector is not None:
                scored = sorted(((name, kind, radd_engines.similarity(vector, emb), g_age) for name, kind, emb, g_age in gallery),
                                key=lambda x: x[2], reverse=True)
                wrong = [(n, k, s, a) for n, k, s, a in scored if n != person['name']]
                row.update(best_wrong=wrong[0][0], best_wrong_kind=wrong[0][1],
                           best_wrong_similarity=round(wrong[0][2], 3),
                           cands=[(s, a, k) for _, k, s, a in wrong[:50]])
                if is_reg:
                    rank = next(i for i, x in enumerate(scored, 1) if x[0] == person['name'])
                    row.update(rank=rank, correct_similarity=round(scored[rank - 1][2], 3))
                policy = Policy(args.threshold, args.child_threshold, args.child_max_age)
                row.update(correct_shown=policy.correct_shown(row, person['reg_age'], args.top_k) if is_reg else '',
                           wrong_shown=policy.wrong_shown(row))
            row['reg_age'] = person['reg_age'] if is_reg else None
            rows.append(row)
            if not args.quiet and person['source'] == 'own':
                log('  ' + describe(row, args))

    write_results(root, rows, gallery, args, time.perf_counter() - started)


def describe(row, args):
    where = f"{row['person']}/{row['photo']}"
    if not row['face_detected']:
        return f'{where}: NO FACE detected'
    if row['registered']:
        shown = row['correct_shown']
        return (f"{where}: rank {row['rank']}, similarity {row['correct_similarity']:.3f}, "
                f"{'shown' if shown else 'NOT shown'}  (best wrong {row['best_wrong_similarity']:.3f})")
    wrong = row['wrong_shown']
    return (f"{where}: not registered, {'WRONG person shown' if wrong else 'nobody shown (correct)'} "
            f"(best {row['best_wrong_similarity']:.3f}, {row['best_wrong_kind']})")


# ---------------------------------------------------------------- results

class Policy:
    """Which candidates the app would show: adults use `adult`, registered people aged
    <= child_max_age use `child` (if set)."""

    def __init__(self, adult, child=None, child_max_age=17):
        self.adult, self.child, self.child_max_age = adult, child, child_max_age

    def threshold(self, age):
        if self.child is not None and age is not None and age <= self.child_max_age:
            return self.child
        return self.adult

    def passing_wrong(self, row):
        return [(s, a, k) for s, a, k in row.get('cands', []) if s >= self.threshold(a)]

    def wrong_shown(self, row):
        return bool(self.passing_wrong(row))

    def correct_shown(self, row, reg_age, top_k):
        c = row['correct_similarity']
        if c < self.threshold(reg_age):
            return False
        return sum(s > c for s, _, _ in self.passing_wrong(row)) < top_k


def metrics(rows, policy, top_k):
    reg = [r for r in rows if r['registered']]
    det = [r for r in rows if r['face_detected']]
    ok = [r for r in reg if r['face_detected']]
    kinds = collections.Counter()
    for r in det:
        passing = policy.passing_wrong(r)
        if passing:
            kinds[max(passing)[2]] += 1
    return dict(
        photos=len(rows), registered=len(reg),
        detected=len(det),
        rank1=sum(r['rank'] == 1 for r in ok),
        top=sum(r['rank'] <= top_k for r in ok),
        shown=sum(policy.correct_shown(r, r['reg_age'], top_k) for r in ok),
        false=sum(kinds.values()),
        false_kinds=kinds)


def block(title, rows, args):
    m = metrics(rows, Policy(args.threshold, args.child_threshold, args.child_max_age), args.top_k)
    lines = [f'[{title}]  found photos {m["photos"]} ({m["registered"]} of registered people)',
             f'  face detected:                   {rate(m["detected"], m["photos"], ci=False)}']
    if m['registered']:
        lines += [f'  correct person ranked 1st:       {rate(m["rank1"], m["registered"])}',
                  f'  correct person in top {args.top_k}:         {rate(m["top"], m["registered"])}',
                  f'  shown in app (>= threshold):     {rate(m["shown"], m["registered"])}']
    lines.append(f'  wrong person shown if not registered: {rate(m["false"], m["detected"])}')
    if m['false']:
        kinds = ', '.join(f'{KIND_LABELS.get(k, k)} {n}' for k, n in m['false_kinds'].most_common())
        lines.append(f'    wrong person was: {kinds}')
    return lines


def threshold_table(rows, args):
    if args.child_threshold is None:
        lines = ['  threshold (everyone) | correct person shown | wrong person shown if not registered']
        sweep = [(t, Policy(t)) for t in sorted(set(THRESHOLD_TABLES[args.engine] + [args.threshold]))]
        current = args.threshold
    else:
        lines = [f'  child threshold (age <= {args.child_max_age}; adults stay {args.threshold}) | correct person shown | '
                 'wrong person shown if not registered']
        sweep = [(t, Policy(args.threshold, t, args.child_max_age))
                 for t in sorted(set(THRESHOLD_TABLES[args.engine] + [args.child_threshold, args.threshold]))]
        current = args.child_threshold
    for t, policy in sweep:
        m = metrics(rows, policy, args.top_k)
        mark = '  <- current' if abs(t - current) < 1e-9 else ''
        lines.append(f'  {t:20.3f} | {rate(m["shown"], m["registered"], ci=False):20} | '
                     f'{rate(m["false"], m["detected"], ci=False)}{mark}')
    return lines


def write_results(root, rows, gallery, args, seconds):
    out = root / 'results'
    out.mkdir(exist_ok=True)
    fields = ['source', 'person', 'photo', 'age', 'registered', 'gap_years', 'condition', 'face_detected',
              'rank', 'correct_similarity', 'correct_shown', 'best_wrong', 'best_wrong_kind', 'best_wrong_similarity',
              'wrong_shown']
    with open(out / 'results.csv', 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)

    lines = [f'Radd photo test -- {datetime.now():%Y-%m-%d %H:%M}',
             f'engine {args.engine}, threshold {args.threshold}'
             + (f', child threshold {args.child_threshold} (age <= {args.child_max_age})' if args.child_threshold is not None else '')
             + f', top {args.top_k}, gallery {len(gallery)} people', '']
    sources = [('ALL', rows), ('YOUR PHOTOS', [r for r in rows if r['source'] == 'own']),
               ('AGEDB CHILDREN', [r for r in rows if r['source'] == 'agedb'])]
    for title, group in sources:
        if group:
            lines += block(title, group, args) + ['']
    lines.append('By condition (all sources):')
    by_condition = collections.defaultdict(list)
    for r in rows:
        by_condition[r['condition']].append(r)
    for condition in sorted(by_condition):
        lines += block(condition, by_condition[condition], args)
    lines += ['', 'Threshold table (ALL), from the same scores:'] + threshold_table(rows, args)
    if any(r['source'] == 'own' for r in rows) and any(r['source'] == 'agedb' for r in rows):
        lines += ['', 'Threshold table (YOUR PHOTOS):'] + threshold_table([r for r in rows if r['source'] == 'own'], args)
    lines += ['', 'Notes: "wrong person shown if not registered" uses every found photo with a face; registered',
              'people are removed from the gallery for this check (leave-one-out). Small samples: read the 95% CI.',
              f'Run took {seconds:.0f}s. No photos or embeddings of your photos were saved.']
    text = '\n'.join(lines)
    (out / 'summary.txt').write_text(text + '\n')
    log('')
    log(text)
    log(f'\nSaved {out / "results.csv"} and {out / "summary.txt"}')


# ---------------------------------------------------------------- main

def snapshot(root):
    base = root / 'people'
    if not base.is_dir():
        return ()
    return tuple(sorted((str(p.relative_to(base)), p.stat().st_size, p.stat().st_mtime_ns) for p in images(base)))


def main():
    ap = argparse.ArgumentParser(description='Reusable Radd face-matching test for new photos.')
    ap.add_argument('--folder', default=str(Path.home() / 'RaddTest'), help='test folder (default ~/RaddTest)')
    ap.add_argument('--data', help='folder containing agedb/ and lfw/ (e.g. .../Radd/ai/data)')
    ap.add_argument('--gallery-size', type=int, default=100, help='registered people at the "event" (default 100)')
    ap.add_argument('--threshold', type=float,
                    help='default: 0.30 for arcface/arcface100 (adults, as in the app), 0.596 for facenet512')
    ap.add_argument('--top-k', type=int, default=5, help='candidates shown in the app (default 5)')
    ap.add_argument('--child-threshold', type=float, help='stricter threshold for registered people aged <= '
                                                           '--child-max-age (default: same as --threshold)')
    ap.add_argument('--child-max-age', type=int, default=17, help='app age bands 0-5 and 6-17 (default 17)')
    ap.add_argument('--engine', choices=['facenet512', 'arcface', 'arcface100'], default='arcface')
    ap.add_argument('--arcface-model', default=str(Path.home() / 'RaddModels' / 'w600k_r50.onnx'))
    ap.add_argument('--no-agedb', action='store_true', help='test your photos only (AgeDB/LFW still fill the gallery)')
    ap.add_argument('--watch', action='store_true', help='re-test automatically whenever people/ changes')
    ap.add_argument('--quiet', action='store_true', help='summary only, no per-photo lines')
    args = ap.parse_args()
    if args.threshold is None:
        args.threshold = DEFAULT_THRESHOLD[args.engine]

    root = Path(args.folder).expanduser().resolve()
    (root / 'people').mkdir(parents=True, exist_ok=True)
    data = Path(args.data).expanduser().resolve() if args.data else None
    if data and not data.is_dir():
        raise SystemExit(f'--data folder not found: {data}')
    if not data:
        log('note: no --data given, so the gallery only contains your registered people.')

    embedder = Embedder(root / '.cache' / f'reference_embeddings_{args.engine}.json', args.engine, args.arcface_model)
    run(root, data, args, embedder)
    if not args.watch:
        return
    log(f'\nWatching {root / "people"} -- add or rename photos and the test re-runs. Ctrl+C to stop.')
    last = snapshot(root)
    try:
        while True:
            time.sleep(3)
            now = snapshot(root)
            if now == last:
                continue
            time.sleep(3)  # let copies finish
            if snapshot(root) != now:
                continue
            last = now
            log(f'\n===== change detected, re-testing ({datetime.now():%H:%M:%S}) =====')
            run(root, data, args, embedder)
    except KeyboardInterrupt:
        log('\nStopped.')


if __name__ == '__main__':
    main()
