"""Pydantic schematy dla habits-service."""
from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, Field


class HabitCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    target_per_week: int = Field(ge=1, le=7, default=7)


class HabitUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    target_per_week: int | None = Field(default=None, ge=1, le=7)


class HabitResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    description: str | None
    target_per_week: int
    created_at: datetime

    model_config = {"from_attributes": True}


class HabitLogCreate(BaseModel):
    logged_on: date | None = None  # domyślnie dzisiaj
    note: str | None = Field(default=None, max_length=500)


class HabitLogResponse(BaseModel):
    id: UUID
    habit_id: UUID
    logged_on: date
    note: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class HabitStats(BaseModel):
    habit_id: UUID
    total_logs: int
    current_streak_days: int
    longest_streak_days: int
    completion_rate_7d: float  # 0.0 - 1.0
    last_logged_on: date | None
