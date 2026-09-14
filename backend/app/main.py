import logging
from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from .firebase import identity
from .models import ProfileCreate, ProfileUpdate, IndividualInput
from .service import GuardianService

app = FastAPI(title="Radd Guardian API", version="0.1.0")

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
    response = await call_next(request)
    route = request.scope.get("route")
    logging.getLogger("uvicorn.error").info("Radd API: %s %s -> %s", request.method, getattr(route, "path", "/unknown"), response.status_code)
    response.headers["Cache-Control"] = "no-store"
    return response

@app.exception_handler(RequestValidationError)
async def invalid(request, error):
    return JSONResponse(status_code=422, content={"detail": "invalid_input"})

@app.exception_handler(Exception)
async def unavailable(request, error):
    return JSONResponse(status_code=503, content={"detail": "service_unavailable"})

def service(token=Depends(identity)):
    return GuardianService(token)

@app.get("/health")
def health():
    return {"status": "ok"}  # Liveness only; does not claim Firebase connectivity.

@app.get("/v1/session")
def session(s=Depends(service)):
    return s.account_role()

@app.get("/v1/guardian")
def profile(s=Depends(service)):
    return s.profile()

@app.put("/v1/guardian")
def create_profile(value: ProfileCreate, s=Depends(service)):
    return s.save_profile(value, create=True)

@app.patch("/v1/guardian")
def update_profile(value: ProfileUpdate, s=Depends(service)):
    return s.save_profile(value)

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
    return public_individual(s.get(item_id))

@app.put("/v1/individuals/{item_id}")
def update_individual(item_id: str, value: IndividualInput, s=Depends(service)):
    return s.save(value, item_id)

@app.delete("/v1/individuals/{item_id}", status_code=204)
def delete_individual(item_id: str, s=Depends(service)):
    s.delete(item_id)
    return Response(status_code=204)

@app.get("/v1/individuals/{item_id}/photo")
def photograph(item_id: str, s=Depends(service)):
    return Response(content=s.photo(item_id), media_type="image/jpeg", headers={"Cache-Control": "no-store"})
