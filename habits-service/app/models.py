"""
Modele ORM: Habit + HabitLog.

WAŻNE: habits-service NIE ma własnej tabeli users!
Przechowuje tylko user_id (UUID z JWT). Za integralność odpowiada
JWT wydawany przez auth-service. Zero join'ów między schemami =
luźne sprzężenie między serwisami.
"""
from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import (
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.config import settings
from app.database import Base

SCHEMA = settings.habits_db_schema


class Habit(Base):
    __tablename__ = "habits"
    __table_args__ = {"schema": SCHEMA}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    description = Column(String(500), nullable=True)
    # Typ częstotliwości: daily | weekly | monthly
    frequency_type = Column(String(10), nullable=False, default="weekly")
    # Cel: ile razy w danym okresie (1 dla daily, 1-7 dla weekly, 1-31 dla monthly)
    target_per_frequency = Column(Integer, nullable=False, default=7)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    logs = relationship(
        "HabitLog",
        back_populates="habit",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class HabitLog(Base):
    __tablename__ = "habit_logs"
    __table_args__ = (
        # jeden log na nawyk na dzień
        UniqueConstraint("habit_id", "logged_on", name="uq_habit_day"),
        {"schema": SCHEMA},
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    habit_id = Column(
        UUID(as_uuid=True),
        ForeignKey(f"{SCHEMA}.habits.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    logged_on = Column(Date, nullable=False, default=date.today)
    note = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    habit = relationship("Habit", back_populates="logs")
