"""Explicit, event-scoped face-embedding backfill; dry-run unless --apply is given.

Never imported by backend startup. Output contains aggregate counts only.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from app import face_matching
from app.events import active_event
from app.firebase import firebase_app, database, bucket
from app.registration_retention import registration_available


def eligible(data, guardian, event_id, uid, item_id):
    """Only owned, available registrations with an immutable private photo reference."""
    path = data.get('photo_path')
    return (guardian.get('role') == 'guardian' and guardian.get('active') is not False
            and data.get('guardian_id') == uid and data.get('event_id') == event_id
            and face_matching.EMBEDDING_FIELD not in data
            and registration_available(data)
            and isinstance(path, str)
            and path.startswith(f'guardians/{uid}/individuals/{item_id}/'))


def backfill(db, storage, event_id, *, dry_run=True, limit=None):
    """Preview without downloads/inference, or embed outside a fenced transaction.

    Existing values, including null, are final. A model failure aborts the run;
    earlier writes remain safe to resume because only missing fields are visited.
    """
    if limit is not None and limit <= 0:
        raise ValueError('Limit must be positive')
    if active_event(db).id != event_id:
        raise ValueError('Requested event must be the single Active Event')
    counts = dict(scanned=0, eligible=0, written=0, no_face=0, skipped=0,
                  changed=0, photo_errors=0)
    engine = None
    guardians = db.collection('users').where(filter=FieldFilter('role', '==', 'guardian'))
    for guardian in guardians.stream():
        people = guardian.reference.collection('individuals').where(
            filter=FieldFilter('event_id', '==', event_id))
        for person in people.stream():
            if limit is not None and counts['eligible'] >= limit:
                return counts
            counts['scanned'] += 1
            data = person.to_dict() or {}
            if not eligible(data, guardian.to_dict() or {}, event_id, guardian.id, person.id):
                counts['skipped'] += 1
                continue
            counts['eligible'] += 1
            if dry_run:
                continue
            if engine is None:
                engine = face_matching.get_engine()
                if engine is None:
                    raise face_matching.Unavailable()
            try:
                content = storage.blob(data['photo_path']).download_as_bytes()
            except Exception:
                # Missing/unreadable photos remain missing, eligible for a later retry.
                counts['photo_errors'] += 1
                continue
            embedding = engine.embed(content)

            @firestore.transactional
            def save(tx):
                current = person.reference.get(transaction=tx).to_dict() or {}
                owner = guardian.reference.get(transaction=tx).to_dict() or {}
                event = active_event(db, tx)
                if (event.id != event_id
                        or not eligible(current, owner, event_id, guardian.id, person.id)
                        or current.get('photo_path') != data['photo_path']
                        or current.get('photo_captured_at') != data.get('photo_captured_at')):
                    return False
                tx.update(person.reference, {face_matching.EMBEDDING_FIELD: embedding})
                return True

            if save(db.transaction()):
                counts['written'] += 1
                counts['no_face'] += embedding is None
            else:
                counts['changed'] += 1
    return counts


def positive_int(value):
    result = int(value)
    if result <= 0:
        raise argparse.ArgumentTypeError('Must be positive')
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, help='Explicit Firebase project ID')
    parser.add_argument('--event-id', required=True, help='The single current Active Event')
    parser.add_argument('--limit', type=positive_int, help='Maximum eligible registrations')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--dry-run', action='store_true', help='Read-only preview (default)')
    mode.add_argument('--apply', action='store_true', help='Download photos, run AI and write missing fields')
    args = parser.parse_args(argv)
    if args.apply and face_matching.get_engine() is None:
        parser.error('Apply requires RADD_FACE_MATCHING=on')
    try:
        if firebase_app().project_id != args.project:
            parser.error('Configured Firebase project does not match --project')
        counts = backfill(database(), bucket(), args.event_id,
                          dry_run=not args.apply, limit=args.limit)
    except face_matching.Unavailable:
        print('Backfill aborted: face matching unavailable. Earlier writes can be resumed safely.')
        return 1
    except Exception:
        # SDK/model exceptions can contain identifiers or data: never print them.
        print('Backfill aborted: check configuration and service availability. Earlier writes can be resumed safely.')
        return 1
    print('Apply' if args.apply else 'Dry-run', counts)
    return 1 if counts['photo_errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
