"""
habits-service — entrypoint FastAPI.

Odpowiedzialność:
- CRUD nawyków użytkownika (tylko swoich)
- logowanie wykonania nawyku (max 1 wpis / dzień / nawyk)
- statystyki (streak, completion rate)

Nie ma własnych userów — ufa JWT wydanemu przez auth-service.
"""
import logging

from fastapi import FastAPI

from app.database import Base, engine
from app.errors import register_error_handlers
from app.routers import habits

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Habits Service",
    description="Zarządzanie nawykami + logi aktywności + statystyki.",
    version="1.0.0",
)

register_error_handlers(app)
app.include_router(habits.router)


@app.get("/health", tags=["internal"], summary="Liveness probe")
def health():
    return {"status": "ok", "service": "habits-service"}
