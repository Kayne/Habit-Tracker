"""Model ORM użytkownika."""
from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, String
from sqlalchemy.dialects.postgresql import UUID

from app.config import settings
from app.database import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": settings.auth_db_schema}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    email = Column(String(254), unique=True, nullable=False, index=True)
    # bcrypt hash — NIGDY plain text
    password_hash = Column(String(255), nullable=False)
    display_name = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
