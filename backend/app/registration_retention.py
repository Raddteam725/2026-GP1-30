"""Event-configured registration retention; no photo-age lifetime or implicit migration."""
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from .case_models import STAGES


def utc_now():
    return datetime.now(timezone.utc)


def timestamp(value):
    return isinstance(value, datetime) and value.tzinfo is not None


def valid_periods(event, now=None):
    now = now or utc_now()
    data = event.to_dict()
    start, end = data.get('starts_at'), data.get('ends_at')
    options = data.get('registration_periods')
    if not timestamp(start) or not timestamp(end) or end <= start or not isinstance(options, list):
        raise HTTPException(503, detail='registration_configuration_required')
    if data.get('active') is not True or not start <= now < end:
        raise HTTPException(409, detail='registration_unavailable')
    valid, ids = [], set()
    for option in options:
        if not isinstance(option, dict):
            raise HTTPException(503, detail='registration_configuration_required')
        key, hours = option.get('id'), option.get('duration_hours')
        if not isinstance(key, str) or not key or '/' in key or key in ids or type(hours) is not int or not 0 < hours <= 87600:
            raise HTTPException(503, detail='registration_configuration_required')
        ids.add(key)
        if now + timedelta(hours=hours) <= end:
            valid.append({'id': key, 'duration_hours': hours})
    if not valid:
        raise HTTPException(409, detail='registration_unavailable')
    return sorted(valid, key=lambda p: (p['duration_hours'], p['id']))


def establish(event, period_id=None):
    now = utc_now()
    options = valid_periods(event, now)
    selected = options[-1] if period_id is None else next((p for p in options if p['id'] == period_id), None)
    if selected is None:
        raise HTTPException(422, detail='invalid_registration_period')
    return {'registration_started_at': now,
            'registration_expires_at': now + timedelta(hours=selected['duration_hours']),
            'registration_period_id': selected['id'],
            'registration_duration_hours': selected['duration_hours']}


def known_period(data):
    start, end = data.get('registration_started_at'), data.get('registration_expires_at')
    return timestamp(start) and timestamp(end) and start < end and bool(data.get('event_id'))


def active_case_required(data, db, tx=None):
    case_id = data.get('active_case_id')
    if not case_id or db is None:
        return False
    case = db.collection('cases').document(case_id).get(transaction=tx).to_dict() or {}
    return (case.get('status') in STAGES[:-1]
            and case.get('guardian_id') == data.get('guardian_id')
            and case.get('event_id') == data.get('event_id'))


def registration_available(data, db=None, tx=None, *, case_context=False):
    if data.get('deleting') or not known_period(data):
        return False
    if data['registration_started_at'] > utc_now():
        return False
    # A deletion hold never renews general registration eligibility.
    return data['registration_expires_at'] > utc_now() or (case_context and active_case_required(data, db, tx))


def validate_configuration(current, proposed):
    """Trusted management boundary, reused by the dev CLI; no Admin endpoint."""
    start, end = proposed.get('starts_at'), proposed.get('ends_at')
    if not timestamp(start) or not timestamp(end) or end <= start:
        raise ValueError('Timezone-aware starts_at < ends_at required')
    if current.get('active') or current.get('activated_at'):
        if current.get('starts_at') is not None and current['starts_at'] != start:
            raise ValueError('An activated event start cannot change')
        if current.get('ends_at') is not None and end < current['ends_at']:
            raise ValueError('An activated event end cannot be shortened')
    class Snapshot:
        def to_dict(self):
            return {**proposed, 'active': True}
    # Validate schema and at least one period fits in the event's full window.
    valid_periods(Snapshot(), start)
