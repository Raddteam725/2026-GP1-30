"""Dedicated Found Report lifecycle and shared reunification context helpers."""
import secrets
import unicodedata

IDENTIFYING = 'identification_in_progress'
IDENTIFIED = 'identity_confirmed'
VERIFYING = 'awaiting_guardian_verification'
REUNITED = 'reunited'
ACTIVE = (IDENTIFYING, IDENTIFIED, VERIFYING)
IDENTIFIED_ACTIVE = (IDENTIFIED, VERIFYING)


def found_status(data):
    return data.get('status') or (IDENTIFIED if data.get('matched_profile_id') else IDENTIFYING)


# Short Guardian-readable fallback for ONE active standalone Found Report. The
# document id stays the authoritative internal identifier and is never shown
# as, nor accepted as, the manual verification value. The code is written once
# at identity confirmation, kept unchanged for the report's whole active life
# and dropped by the Reunited allowlist (`minimal_completed`).
VERIFICATION_CODE_LENGTH = 6


def new_verification_code():
    return ''.join(secrets.choice('0123456789') for _ in range(VERIFICATION_CODE_LENGTH))


def normalize_code(value):
    """Tolerate separators (spaces, '#', dashes) and Arabic-Indic numerals;
    anything else stays and therefore fails the comparison."""
    out = []
    for ch in str(value or ''):
        if ch.isspace() or ch in '#-':
            continue
        out.append(str(unicodedata.digit(ch)) if ch.isdigit() else ch)
    return ''.join(out)


def code_eligible(data):
    return bool(data.get('matched_profile_id')) and not data.get('case_id') and not data.get('ended') \
        and found_status(data) in IDENTIFIED_ACTIVE


def ensure_verification_code(db, doc):
    """Return the report's code, assigning one (once) to an active standalone
    report created before short codes existed. Ineligible reports get none."""
    from firebase_admin import firestore
    data = doc.to_dict() or {}
    if data.get('verification_code'):
        return data['verification_code']
    if not code_eligible(data):
        return None

    @firestore.transactional
    def assign(tx):
        current = doc.reference.get(transaction=tx).to_dict() or {}
        if current.get('verification_code'):
            return current['verification_code']
        if not code_eligible(current):
            return None
        code = new_verification_code()
        tx.update(doc.reference, {'verification_code': code})
        return code
    return assign(db.transaction())


def minimal_completed(data):
    """Approved allowlist: no person/Guardian links, snapshots or QR secrets."""
    proof = data.get('guardian_verification') or {}
    return {'origin': 'volunteer_found', 'event_id': data['event_id'],
            'status': REUNITED, 'created_at': data.get('created_at'),
            'updated_at': data.get('handed_over_at'),
            'handed_over_at': data.get('handed_over_at'),
            'handed_over_by': data.get('handed_over_by'),
            'verification_method': proof.get('method') or data.get('verification_method')}


def identified_report(db, registration, tx=None):
    report_id = registration.get('active_found_report_id')
    if not report_id:
        return None
    doc = db.collection('found_reports').document(report_id).get(transaction=tx)
    data = doc.to_dict() or {}
    if data.get('case_id'):
        from .case_models import TERMINAL_STATUSES
        case = db.collection('cases').document(data['case_id']).get(transaction=tx).to_dict() or {}
        if case.get('status') in TERMINAL_STATUSES:
            return None
    if (found_status(data) in IDENTIFIED_ACTIVE and not data.get('ended')
            and data.get('guardian_id') == registration.get('guardian_id')
            and data.get('event_id') == registration.get('event_id')):
        return doc
    return None


def monitoring(db, event_id, *, active_only=True):
    """Internal trusted Admin service contract; no public/admin UI endpoint.

    The future Admin API must authorize its caller before invoking this function.
    Never returns photo paths, contact information or verification secrets.
    """
    from google.cloud.firestore_v1.base_query import FieldFilter
    fields = ('event_id', 'volunteer_uid', 'created_at', 'updated_at',
              'matched_profile_id', 'handed_over_at', 'handed_over_by', 'verification_method')
    return [{'id': d.id, 'origin': 'volunteer_found', 'status': found_status(d.to_dict()),
             **{k: d.to_dict().get(k) for k in fields}}
            for d in db.collection('found_reports').where(filter=FieldFilter('event_id', '==', event_id)).stream()
            if not active_only or (not d.to_dict().get('ended') and found_status(d.to_dict()) in ACTIVE)]


def context_fields(doc):
    standalone = doc.reference.path.startswith('found_reports/')
    return {'context_type': 'found_report' if standalone else 'missing_case',
            'context_id': doc.id, **({} if standalone else {'case_id': doc.id})}


def proof_context(proof):
    return proof.get('context_id') or proof.get('case_id')
