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
    assert shown == [{'id': report['id'], 'status': 'identity_confirmed',
                      'individual_id': identifier, 'verification_code': code}]
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
    assert not vol('two').verify_guardian_identifier(linked['id'], '123456')['verified']
    assert vol('two').verify_guardian_identifier(linked['id'], '#' + case_id.lower())['verified']
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


def test_no_code_before_identity_or_for_ended_and_case_linked_reports(db):
    guardian, identifier = guardian_with_individual('guardian')
    camera = submit()
    assert 'verification_code' not in db.data['found_reports/' + camera['id']]
    doc = vol().found_owned(camera['id'])
    assert found_reports.ensure_verification_code(db, doc) is None
    assert 'verification_code' not in db.data['found_reports/' + camera['id']]
    vol().end_identification(camera['id'])
    assert found_reports.ensure_verification_code(db, vol().found_owned(camera['id'])) is None
