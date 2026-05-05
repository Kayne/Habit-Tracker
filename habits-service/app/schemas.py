"""Pydantic schematy dla habits-service."""
from datetime import date, datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class FrequencyType(str, Enum):
    daily = "daily"
    weekly = "weekly"
    monthly = "monthly"


# Maksymalna wartość target_per_frequency dla każdego typu częstotliwości.
_MAX_TARGET: dict[FrequencyType, int] = {
    FrequencyType.daily: 99,   # np. 5× dziennie woda, 8× dziennie leki itp.
    FrequencyType.weekly: 7,
    FrequencyType.monthly: 31,
}

# Domyślna wartość target_per_frequency dla każdego typu częstotliwości.
_DEFAULT_TARGET: dict[FrequencyType, int] = {
    FrequencyType.daily: 1,
    FrequencyType.weekly: 7,
    FrequencyType.monthly: 1,
}


class HabitCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    frequency_type: FrequencyType = FrequencyType.weekly
    # Cel: ile razy w danym okresie (daily → max 99, weekly → max 7, monthly → max 31)
    target_per_frequency: int = Field(ge=1, le=99, default=7)

    @model_validator(mode="after")
    def validate_target_for_frequency(self) -> "HabitCreate":
        max_t = _MAX_TARGET[self.frequency_type]
        if self.target_per_frequency > max_t:
            raise ValueError(
                f"target_per_frequency must be ≤ {max_t} for {self.frequency_type} habits"
            )
        return self


class HabitUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    frequency_type: FrequencyType | None = None
    target_per_frequency: int | None = Field(default=None, ge=1, le=99)

    @model_validator(mode="after")
    def validate_target_for_frequency(self) -> "HabitUpdate":
        if self.frequency_type is not None and self.target_per_frequency is not None:
            max_t = _MAX_TARGET[self.frequency_type]
            if self.target_per_frequency > max_t:
                raise ValueError(
                    f"target_per_frequency must be ≤ {max_t} for {self.frequency_type} habits"
                )
        return self


class HabitResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    description: str | None
    frequency_type: str
    target_per_frequency: int
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
    # Wskaźnik ukończenia za bieżący okres (0.0–1.0):
    #   daily   → dni zalogowane w ost. 7 dniach / 7
    #   weekly  → dni zalogowane w ost. 7 dniach / target_per_frequency
    #   monthly → dni zalogowane w ost. 30 dniach / target_per_frequency
    completion_rate_current_period: float
    last_logged_on: date | None
