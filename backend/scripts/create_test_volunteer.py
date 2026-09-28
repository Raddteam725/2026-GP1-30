"""Preview-first local test provisioning using ADC; never a public API."""
import argparse
import getpass
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from firebase_admin import auth, firestore
from app.firebase import firebase_app, database
from scripts.provision_volunteer import provision

PROJECT = 'radd-32eb6'


def inspect(db, app, *, email, name, phone, volunteer_id, existing_uid=None):
    if app.project_id != PROJECT:
        raise ValueError('Unexpected Firebase project; expected radd-32eb6')
    try:
        user = auth.get_user_by_email(email, app=app)
    except auth.UserNotFoundError:
        user = None
    matches = list(db.collection('users').where(filter=firestore.FieldFilter(
        'volunteer_id', '==', volunteer_id)).stream())
    if any(user is None or doc.id != user.uid for doc in matches):
        raise ValueError('Volunteer ID already in use by another profile')
    if existing_uid and (user is None or existing_uid != user.uid):
        raise ValueError('Existing UID does not match the requested email')
    if user is None:
        return None, 'create-auth-and-profile'
    if user.disabled or not any(p.provider_id == 'password' for p in user.provider_data):
        raise ValueError('Existing Auth account is disabled or lacks password sign-in')
    profile = db.collection('users').document(user.uid).get()
    if profile.exists:
        expected = dict(role='volunteer', active=True, full_name=name,
                        email=user.email, phone=phone, volunteer_id=volunteer_id)
        current = profile.to_dict()
        if not all(current.get(k) == v for k, v in expected.items()):
            raise ValueError('Existing profile differs; refusing to overwrite it')
        return user, 'already-provisioned-no-changes'
    if existing_uid != user.uid:
        raise ValueError('Auth email already exists without a profile. Confirm its UID and use --existing-uid; no changes made')
    return user, 'create-profile-for-confirmed-existing-auth'


def execute(db, app, args, *, password_reader=getpass.getpass):
    user, operation = inspect(db, app, email=args.email, name=args.name,
        phone=args.phone, volunteer_id=args.volunteer_id, existing_uid=args.existing_uid)
    print(f'Project: {app.project_id}\nEmail: {args.email}\nVolunteer ID: {args.volunteer_id}')
    print(f'Role: volunteer\nActive: true\nName: {args.name}\nPhone: {args.phone}')
    print('Firestore path: users/' + (user.uid if user else '<Firebase-generated UID>'))
    print('Operation:', operation)
    if not args.apply:
        print('Preview only. No Auth/Firestore writes and no assignment. Repeat with --apply after review.')
        return
    if operation == 'already-provisioned-no-changes':
        return
    if user is None:
        if not sys.stdin.isatty():
            raise ValueError('Run interactively in your local terminal; password input must be hidden')
        password = password_reader('Temporary password (hidden): ')
        confirmation = password_reader('Repeat password (hidden): ')
        if password != confirmation or len(password) < 6:
            raise ValueError('Passwords must match and meet Firebase password requirements')
        user = auth.create_user(email=args.email, password=password, disabled=False, app=app)
        del password, confirmation
        print('Created Authentication UID:', user.uid)
    try:
        provision(db, user, args.name, args.phone, args.volunteer_id, create_only=True)
    except Exception:
        print('Profile creation failed. Auth account retained; no password changed or account deleted.')
        print('Inspect before retrying with --existing-uid', user.uid)
        raise
    print('Profile created. UID:', user.uid)
    print('Not assigned to an event. Use manage_volunteer.py separately.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ('email', 'name', 'phone', 'volunteer-id'):
        parser.add_argument('--' + field, required=True)
    parser.add_argument('--project', required=True, choices=[PROJECT])
    parser.add_argument('--existing-uid', help='Explicitly confirm an existing Auth-only account; never changes its password')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    for field in ('email', 'name', 'phone', 'volunteer_id'):
        value = getattr(args, field).strip()
        if not value:
            parser.error(field + ' must not be empty')
        setattr(args, field, value)
    try:
        app = firebase_app()
        if app.project_id != args.project:
            raise ValueError('Unexpected Firebase project')
        execute(database(), app, args)
    except ValueError as error:
        parser.exit(1, str(error) + '\n')
    except Exception as error:
        # SDK exceptions may include request details: never print their payloads.
        parser.exit(1, 'Provisioning stopped (' + type(error).__name__ + '). Check ADC/IAM or Firebase setup; no automatic rollback.\n')


if __name__ == '__main__':
    main()
