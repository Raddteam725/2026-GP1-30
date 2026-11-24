"""Fixture data only; no removed Release 2 service is recreated in production."""
from datetime import datetime, timezone

def eligible_profiles(workflow):
    return [workflow.public_registration(doc) for doc in workflow.registrations() if workflow.eligible(doc)]

def historical_closure(service, case_id, status='resolved'):
    db = service.db
    data = db.data['cases/' + case_id]
    now = datetime.now(timezone.utc)
    data.update(status=status, closed_at=now, updated_at=now)
    data.pop('verification_code', None)
    person = db.data['users/' + data['guardian_id'] + '/individuals/' + data['individual_id']]
    person['active_case_id'] = None
    person.pop('active_found_report_id', None)
    if data.get('found_report_id'):
        db.data['found_reports/' + data['found_report_id']].update(ended=True, ended_at=now)
    db.data['users/' + data['guardian_id'] + '/notifications/' + case_id + '-' + status] = {
        'case_id': case_id, 'event_id': data['event_id'], 'kind': 'status_changed',
        'status': status, 'created_at': now, 'read_at': None}
    return service.get(case_id)
