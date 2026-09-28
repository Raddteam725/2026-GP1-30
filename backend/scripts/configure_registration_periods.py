"""ADC-backed development event configuration. Preview unless --apply is explicit."""
import argparse
import sys
from datetime import datetime
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from firebase_admin import firestore
from app.firebase import firebase_app, database
from app.events import active_event
from app.registration_retention import validate_configuration, valid_periods


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project', required=True, choices=['radd-32eb6'])
    p.add_argument('--event-id', required=True)
    p.add_argument('--starts-at', required=True, help='ISO timestamp with timezone')
    p.add_argument('--ends-at', required=True, help='ISO timestamp with timezone')
    p.add_argument('--period', action='append', required=True, help='ID:HOURS (repeat per option)')
    p.add_argument('--actor', required=True)
    p.add_argument('--apply', action='store_true')
    args = p.parse_args()
    app = firebase_app()
    if app.project_id != args.project or not args.actor.strip():
        p.error('Project mismatch or missing operator')
    proposed = {'starts_at': datetime.fromisoformat(args.starts_at.replace('Z', '+00:00')),
                'ends_at': datetime.fromisoformat(args.ends_at.replace('Z', '+00:00')),
                'registration_periods': [dict(id=v.rsplit(':', 1)[0], duration_hours=int(v.rsplit(':', 1)[1])) for v in args.period]}
    db = database()
    def check(tx=None):
        event = active_event(db, tx)
        if event.id != args.event_id:
            raise ValueError('Requested event is not the single current Active Event')
        current = event.to_dict()
        validate_configuration(current, proposed)
        return event, current
    event, current = check()
    print('Project:', app.project_id, 'Event:', event.id)
    print('Existing configuration:', {k: current.get(k) for k in proposed})
    print('Proposed configuration:', proposed)
    class Proposed:
        def to_dict(self): return {**proposed, 'active': True}
    print('Currently valid options:', valid_periods(Proposed()))
    print('Existing registration expirations will NOT change.')
    if not args.apply:
        print('Preview only. Repeat with --apply after review.')
        return
    @firestore.transactional
    def save(tx):
        current_event, current = check(tx)
        tx.update(current_event.reference, {**proposed, 'updated_at': firestore.SERVER_TIMESTAMP,
                                          'updated_by': args.actor, 'activated_at': current.get('activated_at') or firestore.SERVER_TIMESTAMP})
    save(db.transaction())
    print('Event configuration updated. No registrations migrated.')


if __name__ == '__main__':
    main()
