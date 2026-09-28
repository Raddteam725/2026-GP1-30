"""Admin-only local command. Uses existing ADC; not exposed by FastAPI."""
import argparse
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from firebase_admin import auth, firestore
from app.firebase import database, firebase_app

def provision(db, user, name, phone, volunteer_id, *, create_only=False):
    if not all(isinstance(value, str) and value.strip() for value in (user.uid, user.email, name, phone, volunteer_id)):
        raise ValueError('An existing email/password Auth account and non-empty profile fields are required')
    ref = db.collection('users').document(user.uid)
    @firestore.transactional
    def save(tx):
        current = ref.get(transaction=tx)
        if create_only:
            if current.exists:
                raise ValueError('Refusing to overwrite an existing profile')
            duplicates = db.collection('users').where(filter=firestore.FieldFilter(
                'volunteer_id', '==', volunteer_id.strip())).stream(transaction=tx)
            if any(doc.id != user.uid for doc in duplicates):
                raise ValueError('Volunteer ID already in use')
        if current.exists and current.to_dict().get('role') != 'volunteer':
            raise ValueError('Refusing to replace an existing non-Volunteer account')
        data = {'role': 'volunteer', 'full_name': name.strip(), 'email': user.email,
                'phone': phone.strip(), 'volunteer_id': volunteer_id.strip(), 'active': True,
                'updated_at': firestore.SERVER_TIMESTAMP}
        if not current.exists:
            data['created_at'] = firestore.SERVER_TIMESTAMP
        tx.set(ref, data, merge=True)
    save(db.transaction())

def main():
    parser = argparse.ArgumentParser(description='Provision a Volunteer profile for an existing Firebase Auth UID.')
    parser.add_argument('--uid', required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--phone', required=True)
    parser.add_argument('--volunteer-id', required=True)
    args = parser.parse_args()
    user = auth.get_user(args.uid, app=firebase_app())
    provision(database(), user, args.name, args.phone, args.volunteer_id)
    print('Volunteer profile provisioned in the existing project.')

if __name__ == '__main__':
    main()
