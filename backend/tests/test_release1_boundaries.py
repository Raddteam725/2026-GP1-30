"""Removed endpoints and preserved startup/API contracts, without live services."""
from copy import deepcopy
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app import alerts, cases, volunteer_alerts, volunteer_workflow, face_matching
from test_volunteer import db

@pytest.mark.parametrize('enabled', [False, True])
def test_startup_routes_and_removed_services(db, monkeypatch, enabled):
    monkeypatch.setenv('RADD_LOCAL_JOBS', '0')
    monkeypatch.setenv('RADD_FACE_MATCHING', 'on' if enabled else 'off')
    warmups = []
    class Engine:
        def warm_up(self): warmups.append(True)
    monkeypatch.setattr(face_matching, 'get_engine', lambda: Engine())
    before = deepcopy(db.data)
    with TestClient(app) as client:
        assert client.get('/health').json() == {'status': 'ok'}
        response = client.get('/openapi.json')
        assert response.status_code == 200
        paths = response.json()['paths']
        removed = [
            ('GET', '/v1/volunteer/profiles'),
            ('POST', '/v1/volunteer/found-reports/manual'),
            ('POST', '/v1/cases/{case_id}/cancel'),
            ('POST', '/v1/cases/{case_id}/resolve'),
        ]
        for method, path in removed:
            assert path not in paths
            assert client.request(method, path.replace('{case_id}', 'RD-fixture')).status_code in (404, 405)
        for path in ['/v1/volunteer/found-reports/{report_id}/candidates',
                     '/v1/volunteer/found-reports/{report_id}/confirm-match',
                     '/v1/volunteer/found-reports/{report_id}/verify',
                     '/v1/volunteer/found-reports/{report_id}/verify-identifier',
                     '/v1/volunteer/found-reports/{report_id}/handover',
                     '/v1/cases/{case_id}/guided-report']:
            assert path in paths
    assert len(warmups) == int(enabled)
    assert db.data == before
    for owner, name in [(cases.CaseService, 'cancel'), (cases.CaseService, 'resolve'),
                        (cases.CaseService, '_terminate'),
                        (volunteer_workflow.VolunteerWorkflow, 'profiles_list'),
                        (volunteer_workflow.VolunteerWorkflow, 'submit_manual'),
                        (volunteer_workflow, 'ManualFoundInput'),
                        (alerts, 'priority_alert'), (volunteer_alerts, 'distance')]:
        assert not hasattr(owner, name)
