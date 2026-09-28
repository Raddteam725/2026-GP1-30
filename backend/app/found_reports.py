"""Dedicated Found Report lifecycle and shared reunification context helpers."""
IDENTIFYING = 'identification_in_progress'
IDENTIFIED = 'identity_confirmed'
VERIFYING = 'awaiting_guardian_verification'
REUNITED = 'reunited'
ACTIVE = (IDENTIFYING, IDENTIFIED, VERIFYING)
IDENTIFIED_ACTIVE = (IDENTIFIED, VERIFYING)


def found_status(data):
    return data.get('status') or (IDENTIFIED if data.get('matched_profile_id') else IDENTIFYING)


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
