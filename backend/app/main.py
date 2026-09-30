import logging
import time
import re
import os
from contextlib import asynccontextmanager
from .local_jobs import LocalJobs
from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from .firebase import identity
from .models import ProfileCreate, ProfileUpdate, IndividualInput, FcmRegistration, FcmUnregister
from .service import GuardianService

@asynccontextmanager
async def lifespan(app):
    jobs = LocalJobs() if os.getenv('RADD_LOCAL_JOBS') == '1' else None
    if jobs:
        jobs.start()
    try:
        yield
    finally:
        if jobs:
            jobs.stop()

app = FastAPI(title="Radd Shared API", version="0.1.0", lifespan=lifespan)

@app.middleware("http")
async def limits(request: Request, call_next):
    # Bounds JSON/base64 uploads before parsing and avoids PII in validation errors.
    length = request.headers.get("content-length")
    if length and (not length.isdigit() or int(length) > 11_300_000):
        return JSONResponse(status_code=413, content={"detail": "request_too_large"})
    if request.method in ("POST", "PUT", "PATCH"):
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > 11_300_000:
                return JSONResponse(status_code=413, content={"detail": "request_too_large"})
        request._body = bytes(body)
    request_id = request.headers.get('x-radd-request-id', '')
    if not re.fullmatch(r'[0-9]{1,20}-[0-9]{1,8}', request_id):
        request_id = '-'
    logging.getLogger('uvicorn.error').info('Radd request %s T1 received epoch_ms=%d', request_id, time.time()*1000)
    started = time.monotonic()
    response = await call_next(request)
    route = request.scope.get("route")
    logging.getLogger("uvicorn.error").info("Radd request %s API: %s %s -> %s (%d ms)", request_id, request.method, getattr(route, "path", "/unknown"), response.status_code, (time.monotonic() - started) * 1000)
    response.headers["Cache-Control"] = "no-store"
    return response

@app.exception_handler(RequestValidationError)
async def invalid(request, error):
    return JSONResponse(status_code=422, content={"detail": "invalid_input"})

@app.exception_handler(Exception)
async def unavailable(request, error):
    # No PII/tokens in the response; the traceback is server-side only, never returned to the client.
    logging.getLogger("uvicorn.error").error("Radd API: unhandled exception", exc_info=error)
    return JSONResponse(status_code=503, content={"detail": "service_unavailable"})

def service(token=Depends(identity)):
    return GuardianService(token)

@app.get("/health")
def health():
    return {"status": "ok"}  # Liveness only; does not claim Firebase connectivity.

@app.get("/v1/session")
def session(s=Depends(service)):
    return s.account_role()

@app.get("/v1/event")
def current_event(s=Depends(service)):
    # The Active event as Guardian and Volunteer see it -- name, location,
    # dates, hours, status -- read from the same record the Admin manages.
    return s.current_event()

@app.get("/v1/guardian")
def profile(s=Depends(service)):
    return s.profile()

@app.put("/v1/guardian")
def create_profile(value: ProfileCreate, s=Depends(service)):
    return s.save_profile(value, create=True)

@app.post("/v1/guardian/verification")
def account_verification(s=Depends(service)):
    return s.account_verification()

@app.put("/v1/guardian/fcm-registrations")
def register_fcm_token(value: FcmRegistration, s=Depends(service)):
    # Idempotent upsert, scoped to the authenticated Guardian's own
    # subcollection -- no other Guardian's registrations are reachable
    # through this or any other endpoint.
    return s.register_fcm_token(value.token, value.locale)

@app.post("/v1/guardian/fcm-registrations/unregister")
def unregister_fcm_token(value: FcmUnregister, s=Depends(service)):
    # Called at logout so this installation stops being able to receive the
    # signing-out Guardian's pushes. Idempotent -- deleting an already-absent
    # registration is a no-op, so a retried/duplicate call is always safe.
    return s.unregister_fcm_token(value.token)

@app.patch("/v1/guardian")
def update_profile(value: ProfileUpdate, s=Depends(service)):
    return s.save_profile(value)

@app.get("/v1/registration-periods")
def registration_periods(s=Depends(service)):
    from .events import active_event
    from .registration_retention import valid_periods
    s.profile()
    event = active_event(s.db)
    options = valid_periods(event)
    return {'event_id': event.id, 'ends_at': event.to_dict()['ends_at'],
            'options': options, 'default_period_id': options[-1]['id']}

@app.get("/v1/individuals")
def individuals(s=Depends(service)):
    return s.list()

@app.post("/v1/individuals", status_code=201)
def create_individual(value: IndividualInput, s=Depends(service)):
    return s.save(value)

@app.get("/v1/individuals/{item_id}")
def individual(item_id: str, s=Depends(service)):
    if "/" in item_id or not item_id:
        raise HTTPException(404)
    from .service import public_individual
    return public_individual(s.get(item_id), s.db)

@app.put("/v1/individuals/{item_id}")
def update_individual(item_id: str, value: IndividualInput, s=Depends(service)):
    return s.save(value, item_id)

@app.delete("/v1/individuals/{item_id}", status_code=204)
def delete_individual(item_id: str, s=Depends(service)):
    s.delete(item_id)
    return Response(status_code=204)

@app.get("/v1/individuals/{item_id}/retention-options")
def retention_options(item_id: str, s=Depends(service)):
    if "/" in item_id or not item_id:
        raise HTTPException(404)
    return s.retention_options(item_id)

@app.get("/v1/individuals/{item_id}/photo")
def photograph(item_id: str, s=Depends(service)):
    return Response(content=s.photo(item_id), media_type="image/jpeg", headers={"Cache-Control": "no-store"})

from .case_models import CaseCreate, GuidedReport
from .cases import CaseService, public_case

def cases_service(s=Depends(service)):
    return CaseService(s)

@app.get("/v1/cases")
def cases(s=Depends(cases_service)):
    return s.list()

@app.post("/v1/cases", status_code=201)
def report_missing(value: CaseCreate, s=Depends(cases_service)):
    return s.create(value)

@app.get("/v1/cases/{case_id}")
def case(case_id: str, s=Depends(cases_service)):
    return s.get(case_id)

@app.put("/v1/cases/{case_id}/guided-report")
def guided_report(case_id: str, value: GuidedReport, s=Depends(cases_service)):
    return s.save_report(case_id, value)

@app.post("/v1/cases/{case_id}/verification")
def verification(case_id: str, s=Depends(cases_service)):
    return s.verification(case_id)

@app.post("/v1/cases/{case_id}/cancel")
def cancel_case(case_id: str, s=Depends(cases_service)):
    return s.cancel(case_id)

@app.post("/v1/cases/{case_id}/resolve")
def resolve_case(case_id: str, s=Depends(cases_service)):
    return s.resolve(case_id)

@app.get("/v1/notifications")
def notifications(s=Depends(cases_service)):
    return s.list_notifications()

@app.put("/v1/notifications/{notification_id}/read", status_code=204)
def read_notification(notification_id: str, s=Depends(cases_service)):
    s.mark_read(notification_id)
    return Response(status_code=204)

from .volunteer import router as volunteer_router
app.include_router(volunteer_router)

@app.get('/v1/guardian/found-reports')
def guardian_found_reports(s=Depends(service)):
    from .found_reports import found_status, ensure_verification_code, guardian_verification_visible
    from google.cloud.firestore_v1.base_query import FieldFilter
    s.profile()
    from .events import active_event
    event_id = active_event(s.db).id
    # Only this Guardian's standalone reports at a stage where verification
    # information may be shown (see guardian_verification_visible): Reunited
    # and still-identifying reports are excluded by authoritative status.
    # `verification_code` is the short fallback the Guardian reads out; the
    # document id is internal. Older active reports are assigned one here.
    # `individual_name` is the Guardian's own registration name, so the
    # Guardian can tell which code belongs to which individual.
    result = []
    for doc in s.db.collection('found_reports').where(filter=FieldFilter('guardian_id', '==', s.uid)).stream():
        data = doc.to_dict() or {}
        if data.get('event_id') != event_id or not guardian_verification_visible(data):
            continue
        individual_id = data.get('individual_id')
        registration = (s.db.collection('users').document(s.uid).collection('individuals').document(individual_id).get().to_dict() or {}) if individual_id else {}
        result.append({'id': doc.id, 'status': found_status(data), 'individual_id': individual_id,
                       'individual_name': registration.get('full_name'),
                       'verification_code': ensure_verification_code(s.db, doc)})
    return result
