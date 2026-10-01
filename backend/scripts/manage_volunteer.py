"""Explicit ADC-backed development operator CLI; no public Admin endpoint."""
import argparse
import os
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.firebase import database
from app.volunteer_access import VolunteerManagement, assignment_ref


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['assign', 'remove', 'enable', 'deactivate'])
    parser.add_argument('--uid', required=True)
    parser.add_argument('--event-id')
    parser.add_argument('--actor', required=True, help='Accountable developer/operator identifier for audit metadata')
    parser.add_argument('--project', required=True, help='Explicit target Firebase project')
    parser.add_argument('--apply', action='store_true', help='Without this flag the command only reads and previews')
    args = parser.parse_args()
    if args.operation in ('assign', 'remove') and not args.event_id:
        parser.error('--event-id is required for assignment operations')
    if args.operation in ('enable', 'deactivate') and args.event_id:
        parser.error('Account status is independent of event assignment; omit --event-id')
    configured = os.environ.get('FIREBASE_PROJECT_ID', 'radd-32eb6')
    if configured != args.project:
        parser.error('--project must match FIREBASE_PROJECT_ID (default radd-32eb6)')
    db = database()
    user = db.collection('users').document(args.uid).get().to_dict() or {}
    if user.get('role') != 'volunteer':
        parser.error('Target must be an existing Volunteer; no account will be created')
    if args.event_id:
        ref = assignment_ref(db, args.event_id, args.uid)
        if not db.collection('events').document(args.event_id).get().exists:
            parser.error('Event does not exist')
        print(f'Current assignment exists: {ref.get().exists}')
    print(f'Project: {args.project}; UID: {args.uid}; operation: {args.operation}; active: {user.get("active")}')
    if not args.apply:
        print('Preview only. Repeat with --apply to execute this exact operation.')
        return
    VolunteerManagement(db).change(args.uid, actor=args.actor,
        operation=args.operation, event_id=args.event_id)
    print('Operation completed. Firebase Auth identity/password and Guardian data were not modified.')


if __name__ == '__main__':
    main()
