"""Short Guardian-readable verification code for standalone Found Reports.

The full document id (FR-…) stays internal; the Guardian card shows a 6-digit
code bound to ONE active report, stable for its whole active life, verified only
inside the Volunteer's own authorized report context, and dropped at Reunited.
"""
import sys
from pathlib import Path
import pytest
from fastapi import HTTPException
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import volunteer_workflow, service, found_reports
from app.cases import CaseService
from app.case_models import CaseCreate
from app.main import guardian_found_reports
from test_volunteer import db, vol, case
from test_cases import guardian_with_individual
from test_volunteer_workflow import submit, manual, matching, code_of


@pytest.fixture(autouse=True)
def photos(db, monkeypatch):
    monkeypatch.setattr(volunteer_workflow, 'bucket', service.bucket)


def standalone(db, uid='one', request_id='manual-request-00001', guardian_uid='guardian'):
    guardian, identifier = guardian_with_individual(guardian_uid)
    wanted = volunteer_workflow.key(guardian.get(identifier))
    profile = next(p for p in vol(uid).profiles_list() if p['id'] == wanted)
    report = manual(uid, profile_id=profile['id'], request_id=request_id)
    return guardian, identifier, report


def test_code_is_generated_short_numeric_and_never_the_document_id(db):
    guardian, identifier, report = standalone(db)
    code = code_of(db, report['id'])
    assert len(code) == found_reports.VERIFICATION_CODE_LENGTH == 6 and code.isdigit()
    assert code != report['id'] and code not in report['id']
    # Shown to the Guardian, not to the Volunteer payload.
    shown = guardian_found_reports(guardian)
    assert shown == [{'id': report['id'], 'status': 'identity_confirmed', 'individual_id': identifier,
                      'individual_name': 'Missing Person', 'verification_code': code}]
    assert 'verification_code' not in report
    assert 'verification_code' not in vol().public_found(vol().found_owned(report['id']))
    assert not any(p.startswith('cases/') for p in db.data)


def test_code_is_stable_across_reload_resume_and_guardian_reopen(db):
    guardian, identifier, report = standalone(db)
    code = code_of(db, report['id'])
    for _ in range(3):
        assert guardian_found_reports(guardian)[0]['verification_code'] == code
    vol().public_found(vol().found_owned(report['id']))  # Volunteer reload
    vol().begin_verification(report['id'])
    # Confirm Identity again from Manual Review resumes the same report.
    again = manual(profile_id=report['person']['id'], request_id='manual-request-00002')
    assert again['id'] == report['id']
    assert code_of(db, report['id']) == code
    assert guardian_found_reports(guardian)[0]['verification_code'] == code
    assert len([p for p in db.data if p.startswith('found_reports/')]) == 1


def test_correct_code_verifies_wrong_code_and_document_id_fail(db):
    guardian, identifier, report = standalone(db)
    code = code_of(db, report['id'])
    vol().begin_verification(report['id'])
    assert not vol().verify_guardian_identifier(report['id'], report['id'])['verified']  # full FR id refused
    assert not vol().verify_guardian_identifier(report['id'], 'FR-' + code)['verified']
    wrong = str((int(code) + 1) % 10**6).zfill(6)
    assert not vol().verify_guardian_identifier(report['id'], wrong)['verified']
    with pytest.raises(HTTPException) as error:
        vol().handover_found(report['id'])
    assert error.value.detail == 'guardian_verification_required'
    verified = vol().verify_guardian_identifier(report['id'], code)
    assert verified['verified'] and verified['report']['status'] == 'awaiting_guardian_verification'
    assert verified['report']['verification']['method'] == 'found_identifier'
    assert verified['report']['verification']['context_id'] == report['id']
    assert not any(p.startswith('cases/') for p in db.data)


def test_code_tolerates_spacing_hash_and_arabic_indic_digits(db):
    guardian, identifier, report = standalone(db)
    code = code_of(db, report['id'])
    vol().begin_verification(report['id'])
    spaced = '# ' + code[:3] + ' - ' + code[3:]
    assert vol().verify_guardian_identifier(report['id'], spaced)['verified']
    arabic = ''.join('٠١٢٣٤٥٦٧٨٩'[int(ch)] for ch in code)
    assert vol().verify_guardian_identifier(report['id'], arabic)['verified']


def test_another_reports_code_fails_and_is_never_looked_up_globally(db):
    guardian_a, identifier_a, first = standalone(db)
    guardian_b, identifier_b = guardian_with_individual('other-guardian')
    profile_b = next(p for p in vol('two').profiles_list()
                     if p['id'] == volunteer_workflow.key(guardian_b.get(identifier_b)))
    second = manual('two', profile_id=profile_b['id'], request_id='manual-request-00002')
    code_a, code_b = code_of(db, first['id']), code_of(db, second['id'])
    if code_a == code_b:  # astronomically unlikely; make the cross-check meaningful
        db.data['found_reports/' + second['id']]['verification_code'] = code_b = str((int(code_a) + 7) % 10**6).zfill(6)
    vol().begin_verification(first['id'])
    vol('two').begin_verification(second['id'])
    assert not vol().verify_guardian_identifier(first['id'], code_b)['verified']
    assert not vol('two').verify_guardian_identifier(second['id'], code_a)['verified']
    assert vol().verify_guardian_identifier(first['id'], code_a)['verified']
    # Each Guardian sees only their own report's code.
    assert [r['verification_code'] for r in guardian_found_reports(guardian_a)] == [code_a]
    assert [r['verification_code'] for r in guardian_found_reports(guardian_b)] == [code_b]
    with pytest.raises(HTTPException):
        vol('two').verify_guardian_identifier(first['id'], code_a)


def test_code_is_rejected_and_removed_after_reunited(db):
    guardian, identifier, report = standalone(db)
    code = code_of(db, report['id'])
    vol().begin_verification(report['id'])
    assert vol().verify_guardian_identifier(report['id'], code)['verified']
    assert vol().handover_found(report['id'])['status'] == 'reunited'
    assert 'verification_code' not in db.data['found_reports/' + report['id']]
    assert guardian_found_reports(guardian) == []
    with pytest.raises(HTTPException):
        vol().verify_guardian_identifier(report['id'], code)
    # A later report for the same registration gets its own, new code.
    later = manual(profile_id=report['person']['id'], request_id='manual-request-00003')
    assert later['id'] != report['id']
    assert code_of(db, later['id']).isdigit()


def test_qr_verification_and_missing_case_identifier_fallback_are_unchanged(db):
    # Linked Missing Case: still the case identifier, never a short code.
    guardian_c, case_id, linked = matching('two')
    assert linked['case_id'] == case_id
    assert 'verification_code' not in db.data['found_reports/' + linked['id']]
    assert guardian_found_reports(guardian_c) == []
    vol('two').begin_verification(linked['id'])
    case_code = db.data['cases/' + case_id]['verification_code']
    assert len(case_code) == 6 and case_code != '123456'
    assert not vol('two').verify_guardian_identifier(linked['id'], '123456')['verified']
    assert not vol('two').verify_guardian_identifier(linked['id'], '#' + case_id.lower())['verified']  # RD id refused
    assert vol('two').verify_guardian_identifier(linked['id'], '# ' + case_code)['verified']
    # Standalone (a different Guardian): the QR path is untouched by the short code.
    guardian, identifier, report = standalone(db, guardian_uid='other-guardian')
    vol().begin_verification(report['id'])
    assert not vol().verify_guardian(report['id'], guardian_c.account_verification()['payload'])['verified']
    assert vol().verify_guardian(report['id'], guardian.account_verification()['payload'])['verified']
    assert vol().handover_found(report['id'])['status'] == 'reunited'
    assert len([p for p in db.data if p.startswith('cases/')]) == 1


def test_existing_active_report_without_code_gets_one_safely_when_shown(db):
    guardian, identifier, report = standalone(db)
    path = 'found_reports/' + report['id']
    db.data[path].pop('verification_code')  # a report created before short codes
    assert 'verification_code' not in db.data[path]
    before = dict(db.data[path])
    shown = guardian_found_reports(guardian)
    code = shown[0]['verification_code']
    assert len(code) == 6 and code.isdigit()
    assert db.data[path] == {**before, 'verification_code': code}
    assert guardian_found_reports(guardian)[0]['verification_code'] == code  # not regenerated
    assert len([p for p in db.data if p.startswith('found_reports/')]) == 1
    vol().begin_verification(report['id'])
    assert vol().verify_guardian_identifier(report['id'], code)['verified']
    assert not any(p.startswith('cases/') for p in db.data)


def test_guardian_list_follows_authoritative_status_and_names_the_individual(db):
    guardian, identifier = guardian_with_individual('guardian')
    wanted = volunteer_workflow.key(guardian.get(identifier))
    profile = next(p for p in vol().profiles_list() if p['id'] == wanted)
    camera = submit()
    # identification_in_progress: no Guardian relationship confirmed yet, so
    # nothing is listed and no code exists.
    assert guardian_found_reports(guardian) == []
    assert 'verification_code' not in db.data['found_reports/' + camera['id']]
    vol().confirm(camera['id'], profile['id'])
    listed = guardian_found_reports(guardian)
    assert [r['status'] for r in listed] == ['identity_confirmed']
    assert listed[0]['individual_name'] == 'Missing Person'
    assert listed[0]['individual_id'] == identifier
    code = listed[0]['verification_code']
    assert len(code) == 6 and code.isdigit() and code != camera['id']
    vol().begin_verification(camera['id'])
    listed = guardian_found_reports(guardian)
    assert [r['status'] for r in listed] == ['awaiting_guardian_verification']
    assert listed[0]['verification_code'] == code  # same code across stages
    assert vol().verify_guardian_identifier(camera['id'], code)['verified']
    vol().handover_found(camera['id'])
    assert guardian_found_reports(guardian) == []
    assert not any(p.startswith('cases/') for p in db.data)


def test_guardian_list_excludes_legacy_terminal_documents_and_never_backfills_them(db):
    guardian, identifier = guardian_with_individual('guardian')
    wanted = volunteer_workflow.key(guardian.get(identifier))
    profile = next(p for p in vol().profiles_list() if p['id'] == wanted)
    active = manual(profile_id=profile['id'])
    live = dict(db.data['found_reports/' + active['id']])
    # A historical Reunited document that was never minimized: it still
    # carries the Guardian link, the matched profile and an old code.
    db.data['found_reports/FR-legacy-reunited'] = {**live, 'status': 'reunited', 'handed_over_at': live['created_at'],
                                                   'handed_over_by': 'one', 'verification_code': '111111'}
    # A historical handed-over document with no status field at all.
    db.data['found_reports/FR-legacy-nostatus'] = {k: v for k, v in live.items() if k not in ('status', 'verification_code')}
    db.data['found_reports/FR-legacy-nostatus']['handed_over_at'] = live['created_at']
    # A historical ended identification that kept a Guardian link.
    db.data['found_reports/FR-legacy-ended'] = {k: v for k, v in live.items() if k != 'verification_code'} | {'ended': True}
    before = {k: dict(v) for k, v in db.data.items() if k.startswith('found_reports/FR-legacy')}
    listed = guardian_found_reports(guardian)
    assert [r['id'] for r in listed] == [active['id']]
    assert listed[0]['verification_code'] == live['verification_code']
    after = {k: dict(v) for k, v in db.data.items() if k.startswith('found_reports/FR-legacy')}
    assert after == before  # not backfilled, not regenerated, not touched
    assert 'verification_code' not in after['found_reports/FR-legacy-nostatus']
    assert found_reports.ensure_verification_code(db, db.collection('found_reports').document('FR-legacy-nostatus').get()) is None


def test_multiple_active_reports_are_each_named_and_verify_only_with_their_own_code(db):
    guardian, first_id = guardian_with_individual('guardian')
    _, second_id = guardian_with_individual('guardian')  # same Guardian, second individual
    guardian.db.collection('users').document('guardian').collection('individuals').document(second_id).update({'full_name': 'Second Person'})
    keys = {volunteer_workflow.key(guardian.get(i)): i for i in (first_id, second_id)}
    profiles = {keys[p['id']]: p for p in vol().profiles_list() if p['id'] in keys}
    first = manual(profile_id=profiles[first_id]['id'], request_id='manual-request-00001')
    second = manual(profile_id=profiles[second_id]['id'], request_id='manual-request-00002')
    assert first['id'] != second['id']
    listed = {r['id']: r for r in guardian_found_reports(guardian)}
    assert set(listed) == {first['id'], second['id']}
    assert listed[first['id']]['individual_name'] == 'Missing Person'
    assert listed[second['id']]['individual_name'] == 'Second Person'
    assert listed[first['id']]['verification_code'] == code_of(db, first['id'])
    assert listed[second['id']]['verification_code'] == code_of(db, second['id'])
    vol().begin_verification(first['id'])
    vol().begin_verification(second['id'])
    if code_of(db, first['id']) == code_of(db, second['id']):
        db.data['found_reports/' + second['id']]['verification_code'] = str((int(code_of(db, first['id'])) + 3) % 10**6).zfill(6)
    assert not vol().verify_guardian_identifier(first['id'], code_of(db, second['id']))['verified']
    assert vol().verify_guardian_identifier(first['id'], code_of(db, first['id']))['verified']
    assert vol().verify_guardian_identifier(second['id'], code_of(db, second['id']))['verified']
    assert not any(p.startswith('cases/') for p in db.data)


def test_no_code_before_identity_or_for_ended_and_case_linked_reports(db):
    guardian, identifier = guardian_with_individual('guardian')
    camera = submit()
    assert 'verification_code' not in db.data['found_reports/' + camera['id']]
    doc = vol().found_owned(camera['id'])
    assert found_reports.ensure_verification_code(db, doc) is None
    assert 'verification_code' not in db.data['found_reports/' + camera['id']]
    vol().end_identification(camera['id'])
    assert found_reports.ensure_verification_code(db, vol().found_owned(camera['id'])) is None
