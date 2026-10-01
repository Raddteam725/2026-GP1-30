"""6-digit Guardian verification code for Missing Cases.

The RD-… document id stays the case's internal identity (references, logs,
relationships, APIs). The value a Guardian reads to a Volunteer, and the value
the Volunteer types, is the case's own `verification_code`: 6 secure digits,
unique among the event's active cases, persisted once on the case record,
stable for the workflow, removed at every terminal outcome.
"""
import sys
from pathlib import Path
import pytest
from fastapi import HTTPException
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import volunteer_workflow, service, cases as cases_module, found_reports
from app.cases import CaseService, public_case
from app.case_models import CaseCreate
from app.main import app, case as get_case_endpoint
from app.firebase import identity
from test_volunteer import db, vol, case
from test_cases import guardian_with_individual
from test_volunteer_workflow import submit, matching


@pytest.fixture(autouse=True)
def photos(db, monkeypatch):
    monkeypatch.setattr(volunteer_workflow, 'bucket', service.bucket)


def stored(db, case_id):
    return db.data['cases/' + case_id]


def test_case_gets_a_secure_six_digit_code_distinct_from_its_id(db):
    guardian, case_id = case()
    code = stored(db, case_id)['verification_code']
    assert case_id.startswith('RD-') and len(code) == 6 and code.isdigit()
    assert code not in case_id
    shown = CaseService(guardian).get(case_id)
    assert shown['id'] == case_id and shown['verification_code'] == code
    assert [c['verification_code'] for c in CaseService(guardian).list()] == [code]
    # Not on the individual profile; only on this active case record.
    individual = guardian.user.collection('individuals').document(shown['individual_id']).get().to_dict()
    assert 'verification_code' not in individual
    # Never in the Volunteer's view of the case.
    listed = vol().list()
    assert listed and all('verification_code' not in c for c in listed)
    assert 'verification_code' not in str(vol().case_state(case_id))


def test_code_is_stable_across_reads_and_correct_wrong_other_case(db):
    guardian, case_id, report = matching()
    code = stored(db, case_id)['verification_code']
    for _ in range(3):
        assert CaseService(guardian).get(case_id)['verification_code'] == code
    vol().begin_verification(report['id'])
    assert not vol().verify_guardian_identifier(report['id'], case_id)['verified']          # RD-… id refused
    assert not vol().verify_guardian_identifier(report['id'], '#' + case_id.lower())['verified']
    wrong = str((int(code) + 1) % 10**6).zfill(6)
    assert not vol().verify_guardian_identifier(report['id'], wrong)['verified']
    assert stored(db, case_id).get('guardian_verification') is None
    with pytest.raises(HTTPException):
        vol().handover_found(report['id'])
    # Another Guardian's active case code never verifies this case.
    other_guardian, other_id = guardian_with_individual('other')
    other = CaseService(other_guardian).create(CaseCreate(individual_id=other_id))
    other_code = other['verification_code']
    if other_code == code:
        stored(db, other['id'])['verification_code'] = other_code = str((int(code) + 5) % 10**6).zfill(6)
    assert not vol().verify_guardian_identifier(report['id'], other_code)['verified']
    result = vol().verify_guardian_identifier(report['id'], ' ' + code[:3] + '-' + code[3:] + ' ')
    assert result['verified'] and result['report']['verification']['method'] == 'case_identifier'
    assert result['report']['verification']['case_id'] == case_id  # receipt keeps the internal id
    assert vol().verify_guardian_identifier(report['id'], code)['verified']  # lost-response retry
    assert stored(db, case_id)['verification_code'] == code
    assert vol().handover_found(report['id'])['status'] == 'reunited'
    assert 'verification_code' not in stored(db, case_id)
    assert stored(db, case_id)['handed_over_by'] == 'one'
    assert CaseService(guardian).get(case_id)['verification_code'] is None
    with pytest.raises(HTTPException):
        vol().verify_guardian_identifier(report['id'], code)


@pytest.mark.parametrize('outcome', ['cancel', 'resolve'])
def test_guardian_terminal_outcomes_remove_the_code_and_never_backfill(db, outcome):
    guardian, case_id = case()
    getattr(CaseService(guardian), outcome)(case_id)
    assert 'verification_code' not in stored(db, case_id)
    assert CaseService(guardian).get(case_id)['verification_code'] is None
    assert 'verification_code' not in stored(db, case_id)  # a read never backfills a terminal case
    assert [c['verification_code'] for c in CaseService(guardian).list()] == [None]


def test_legacy_active_case_without_code_is_backfilled_once_on_first_read(db):
    guardian, case_id = case()
    before = dict(stored(db, case_id))
    del stored(db, case_id)['verification_code']  # a case created before short codes
    first = CaseService(guardian).list()[0]
    code = first['verification_code']
    assert len(code) == 6 and code.isdigit()
    assert first['id'] == case_id and first['status'] == before['status']
    assert stored(db, case_id) == {**before, 'verification_code': code}
    assert CaseService(guardian).get(case_id)['verification_code'] == code  # stable, not regenerated
    assert len([p for p in db.data if p.startswith('cases/')]) == 1
    app.dependency_overrides[identity] = lambda: {'uid': 'guardian', 'email': 'g@example.test', 'exp': 9999999999, 'auth_time': 1}
    try:
        assert get_case_endpoint(case_id, CaseService(guardian))['verification_code'] == code
    finally:
        app.dependency_overrides.clear()


def test_collision_within_active_scope_retries_and_terminal_codes_do_not_block(db, monkeypatch):
    guardian, first_id = case()
    first_code = stored(db, first_id)['verification_code']
    # Force the generator to produce the taken code first, then a fresh one.
    sequence = iter([first_code, first_code, '000001'])
    monkeypatch.setattr(cases_module, 'new_verification_code', lambda: next(sequence))
    _, second_person = guardian_with_individual('guardian')
    second = CaseService(guardian).create(CaseCreate(individual_id=second_person))
    assert second['verification_code'] == '000001'
    assert second['id'] != first_id
    # A terminal case's old code is out of scope: it may be reused.
    CaseService(guardian).cancel(second['id'])
    sequence = iter(['000001'])
    _, third_person = guardian_with_individual('guardian')
    third = CaseService(guardian).create(CaseCreate(individual_id=third_person))
    assert third['verification_code'] == '000001'
    # Exhausting attempts fails closed rather than issuing a duplicate.
    sequence = iter([first_code] * 30)
    _, fourth_person = guardian_with_individual('guardian')
    with pytest.raises(HTTPException) as error:
        CaseService(guardian).create(CaseCreate(individual_id=fourth_person))
    assert error.value.status_code == 503
    assert len([p for p in db.data if p.startswith('cases/')]) == 3


def test_code_read_through_guardian_http_api_verifies_through_volunteer_http_api(db):
    """End to end over HTTP: the Guardian's own GET returns the code; the
    Volunteer posts THAT value for the SAME case and gets verified=true."""
    from fastapi.testclient import TestClient
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    _, other_person = guardian_with_individual('guardian')
    other = CaseService(guardian).create(CaseCreate(individual_id=other_person))
    guardian_token = {'uid': 'guardian', 'email': 'guardian@example.test', 'exp': 9999999999, 'auth_time': 1}
    volunteer_token = {'uid': 'one', 'exp': 9999999999, 'auth_time': 1}
    try:
        with TestClient(app) as client:
            app.dependency_overrides[identity] = lambda: guardian_token
            shown = client.get(f'/v1/cases/{case_id}').json()
            listed = {c['id']: c for c in client.get('/v1/cases').json()}
            code = shown['verification_code']
            assert shown['id'] == case_id and listed[case_id]['verification_code'] == code
            assert isinstance(code, str) and len(code) == 6 and code.isdigit()
            assert code == stored(db, case_id)['verification_code']
            other_code = listed[other['id']]['verification_code']
            if other_code == code:
                stored(db, other['id'])['verification_code'] = other_code = str((int(code) + 9) % 10**6).zfill(6)
            app.dependency_overrides[identity] = lambda: volunteer_token
            url = f"/v1/volunteer/found-reports/{report['id']}/verify-identifier"
            wrong = client.post(url, json={'case_id': str((int(code) + 1) % 10**6).zfill(6)}).json()
            assert wrong['verified'] is False
            assert client.post(url, json={'case_id': other_code}).json()['verified'] is False
            assert client.post(url, json={'case_id': case_id}).json()['verified'] is False  # RD id is not the code
            # Exactly the value the Guardian API returned, in both accepted body shapes.
            good = client.post(url, json={'case_id': code})
            assert good.status_code == 200 and good.json()['verified'] is True
            assert good.json()['report']['verification']['method'] == 'case_identifier'
            assert client.post(url, json={'identifier': code}).json()['verified'] is True
    finally:
        app.dependency_overrides.clear()
    assert stored(db, case_id)['guardian_verification']['case_id'] == case_id


def test_qr_verification_and_found_report_codes_are_unchanged(db):
    guardian, case_id, report = matching()
    vol().begin_verification(report['id'])
    assert vol().verify_guardian(report['id'], guardian.account_verification()['payload'])['verified']
    assert stored(db, case_id)['guardian_verification']['method'] == 'qr'
    # Standalone Found Report: still its own 6-digit code, still FR id hidden.
    other, identifier = guardian_with_individual('other-guardian')
    wanted = volunteer_workflow.key(other.get(identifier))
    profile = next(p for p in vol('two').profiles_list() if p['id'] == wanted)
    found = vol('two').submit_manual(volunteer_workflow.ManualFoundInput(request_id='manual-request-00009', profile_id=profile['id']))
    found_code = db.data['found_reports/' + found['id']]['verification_code']
    assert len(found_code) == 6 and found_code.isdigit() and 'verification_code' not in found
    vol('two').begin_verification(found['id'])
    assert not vol('two').verify_guardian_identifier(found['id'], found['id'])['verified']
    assert vol('two').verify_guardian_identifier(found['id'], found_code)['verified']
    assert len([p for p in db.data if p.startswith('cases/')]) == 1  # no case created for the standalone report
