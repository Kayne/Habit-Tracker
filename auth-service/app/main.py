"""
auth-service — entrypoint FastAPI.

Odpowiedzialność:
- rejestracja (bcrypt hash hasła)
- logowanie (wydanie JWT)
- weryfikacja tokenu (/auth/me, /auth/verify)
- JEDYNE miejsce w systemie które zna hasła użytkowników
"""
import logging

from fastapi import FastAPI

from app.database import Base, engine
from app.errors import register_error_handlers
from app.routers import auth

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Auth Service",
    description="Rejestracja, logowanie, wydawanie JWT.",
    version="1.0.0",
)

register_error_handlers(app)
app.include_router(auth.router)


@app.get("/health", tags=["internal"], summary="Liveness probe")
def health():
    return {"status": "ok", "service": "auth-service"}
