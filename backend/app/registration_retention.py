"""Event-configured registration retention; no photo-age lifetime or implicit migration.

The retention period is the Guardian's choice at registration (Sprint-0
"Registration Period and Data Retention"): it starts at the successful
registration, cannot extend beyond the event's end, and defines when the
individual's identifiable data is deleted. A Guardian may later change the
choice from the profile (`reschedule`): the start never moves, the new
deadline must still lie in the future and within the event, and the same
edit restrictions as any other profile edit apply (no active case).
"""
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from .case_models import STAGES


def utc_now():
    return datetime.now(timezone.utc)


def timestamp(value):
    return isinstance(value, datetime) and value.tzinfo is not None


def configured_periods(event):
    """The event's configured options, schema-checked; independent of time."""
    data = event.to_dict()
    start, end = data.get('starts_at'), data.get('ends_at')
    options = data.get('registration_periods')
    if not timestamp(start) or not timestamp(end) or end <= start or not isinstance(options, list):
        raise HTTPException(503, detail='registration_configuration_required')
    periods, ids = [], set()
    for option in options:
        if not isinstance(option, dict):
            raise HTTPException(503, detail='registration_configuration_required')
        key, hours = option.get('id'), option.get('duration_hours')
        if not isinstance(key, str) or not key or '/' in key or key in ids or type(hours) is not int or not 0 < hours <= 87600:
            raise HTTPException(503, detail='registration_configuration_required')
        ids.add(key)
        periods.append({'id': key, 'duration_hours': hours})
    return start, end, sorted(periods, key=lambda p: (p['duration_hours'], p['id']))


def valid_periods(event, now=None):
    """Options a NEW registration may choose right now."""
    now = now or utc_now()
    start, end, periods = configured_periods(event)
    if event.to_dict().get('active') is not True or not start <= now < end:
        raise HTTPException(409, detail='registration_unavailable')
    valid = [p for p in periods if now + timedelta(hours=p['duration_hours']) <= end]
    if not valid:
        raise HTTPException(409, detail='registration_unavailable')
    return valid


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


def edit_options(event, data, now=None):
    """Every configured option for an EXISTING registration, each with the
    deadline it would produce (counted from the ORIGINAL start) and whether
    it may be chosen: `available` is False with `reason` 'deadline_passed'
    when that deadline is already behind us, or 'beyond_event' when it would
    end after the event. The current choice is always available (a no-op).
    The client only uses this to disable choices; `reschedule` decides."""
    now = now or utc_now()
    _, end, periods = configured_periods(event)
    if event.to_dict().get('active') is not True or not known_period(data):
        raise HTTPException(409, detail='registration_unavailable')
    started = data['registration_started_at']
    options = []
    for period in periods:
        deadline = started + timedelta(hours=period['duration_hours'])
        current = period['id'] == data.get('registration_period_id')
        reason = 'beyond_event' if deadline > end else 'deadline_passed' if deadline <= now else None
        options.append({**period, 'expires_at': deadline,
                        'available': current or reason is None,
                        'reason': None if current else reason})
    return options


def reschedule(event, data, period_id, now=None):
    """The Guardian changes the retention period of an existing registration.

    Never moves the start. Rejects an option that is not configured or would
    end after the event (422 invalid_registration_period), and one whose
    deadline has already passed (409 retention_deadline_passed) -- a choice
    can never retroactively expire the data.
    """
    now = now or utc_now()
    _, end, periods = configured_periods(event)
    if event.to_dict().get('active') is not True or not known_period(data):
        raise HTTPException(409, detail='registration_unavailable')
    selected = next((p for p in periods if p['id'] == period_id), None)
    if selected is None:
        raise HTTPException(422, detail='invalid_registration_period')
    deadline = data['registration_started_at'] + timedelta(hours=selected['duration_hours'])
    if deadline > end:
        raise HTTPException(422, detail='invalid_registration_period')
    if deadline <= now:
        raise HTTPException(409, detail='retention_deadline_passed')
    return {'registration_expires_at': deadline, 'registration_period_id': selected['id'],
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
