FROM python:3.12-slim

# Bezpieczeństwo: non-root user
RUN groupadd --system app && useradd --system --gid app --home /app app

WORKDIR /app

# Optymalizacja Pythona dla kontenera
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Instalacja zależności systemowych (psycopg2 + curl dla healthcheck)
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpq-dev curl \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app

RUN chown -R app:app /app
USER app

EXPOSE 8001

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=5 \
  CMD curl -fsS http://localhost:8001/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
