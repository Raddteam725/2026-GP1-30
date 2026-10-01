FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY backend/requirements.lock ./requirements.lock
RUN pip install --no-cache-dir -r requirements.lock

RUN useradd --create-home --uid 10001 appuser
COPY --chown=appuser:appuser backend/app ./app
USER appuser

EXPOSE 8080

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1"]
