"""
Połączenie z PostgreSQL + sesja SQLAlchemy.

Ten serwis widzi TYLKO schema `auth_schema` — to ustawiamy przez
search_path na połączeniu.
"""
from sqlalchemy import create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker

from app.config import settings

engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    future=True,
)


@event.listens_for(engine, "connect")
def _set_search_path(dbapi_connection, _connection_record):
    """Każde nowe połączenie widzi tylko swoją schemę."""
    cursor = dbapi_connection.cursor()
    cursor.execute(f"SET search_path TO {settings.auth_db_schema}")
    cursor.close()


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, future=True)
Base = declarative_base()


def get_db():
    """FastAPI dependency — sesja na request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
