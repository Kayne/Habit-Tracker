"""
CRUD nawyków + logi aktywności + statystyki.

KAŻDY endpoint wymaga JWT i operuje TYLKO na nawykach zalogowanego
usera (ownership check na każdej operacji — FORBIDDEN jeśli czyjś).
"""
from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user_id
from app.errors import ConflictError, ForbiddenError, NotFoundError
from app.models import Habit, HabitLog
from app.schemas import (
    HabitCreate,
    HabitLogCreate,
    HabitLogResponse,
    HabitResponse,
    HabitStats,
    HabitUpdate,
)
from app.services.stats import compute_stats

router = APIRouter(prefix="/habits", tags=["habits"])


def _get_owned_habit(db: Session, habit_id: UUID, user_id: UUID) -> Habit:
    habit = db.query(Habit).filter(Habit.id == habit_id).first()
    if not habit:
        raise NotFoundError("Habit not found")
    if habit.user_id != user_id:
        # Świadomie zwracamy 403 (nie 404) — user jest zalogowany,
        # ale zasób nie należy do niego. 404 byłoby też akceptowalne
        # (ukrycie istnienia zasobu), ale tu preferujemy precyzję.
        raise ForbiddenError("You do not own this habit")
    return habit


@router.post(
    "",
    response_model=HabitResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Utwórz nawyk",
)
def create_habit(
    payload: HabitCreate,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    habit = Habit(
        user_id=user_id,
        name=payload.name.strip(),
        description=payload.description,
        frequency_type=payload.frequency_type.value,
        target_per_frequency=payload.target_per_frequency,
    )
    db.add(habit)
    db.commit()
    db.refresh(habit)
    return habit


@router.get(
    "",
    response_model=list[HabitResponse],
    summary="Lista moich nawyków",
)
def list_habits(
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return (
        db.query(Habit)
        .filter(Habit.user_id == user_id)
        .order_by(Habit.created_at.desc())
        .all()
    )


@router.get(
    "/{habit_id}",
    response_model=HabitResponse,
    summary="Szczegóły nawyku",
)
def get_habit(
    habit_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _get_owned_habit(db, habit_id, user_id)


@router.patch(
    "/{habit_id}",
    response_model=HabitResponse,
    summary="Aktualizuj nawyk",
)
def update_habit(
    habit_id: UUID,
    payload: HabitUpdate,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    habit = _get_owned_habit(db, habit_id, user_id)
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(habit, key, value)
    db.commit()
    db.refresh(habit)
    return habit


@router.delete(
    "/{habit_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Usuń nawyk",
)
def delete_habit(
    habit_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    habit = _get_owned_habit(db, habit_id, user_id)
    db.delete(habit)
    db.commit()
    return None


@router.post(
    "/{habit_id}/logs",
    response_model=HabitLogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Zaloguj wykonanie nawyku (domyślnie dzisiaj)",
)
def log_habit(
    habit_id: UUID,
    payload: HabitLogCreate,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    _get_owned_habit(db, habit_id, user_id)
    log = HabitLog(
        habit_id=habit_id,
        logged_on=payload.logged_on or date.today(),
        note=payload.note,
    )
    db.add(log)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise ConflictError(
            "Habit already logged for this date",
            details={"habit_id": str(habit_id), "logged_on": str(log.logged_on)},
        )
    db.refresh(log)
    return log


@router.get(
    "/{habit_id}/logs",
    response_model=list[HabitLogResponse],
    summary="Historia logów nawyku",
)
def list_logs(
    habit_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    _get_owned_habit(db, habit_id, user_id)
    return (
        db.query(HabitLog)
        .filter(HabitLog.habit_id == habit_id)
        .order_by(HabitLog.logged_on.desc())
        .all()
    )


@router.get(
    "/{habit_id}/stats",
    response_model=HabitStats,
    summary="Statystyki nawyku (streak, completion rate)",
)
def habit_stats(
    habit_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    _get_owned_habit(db, habit_id, user_id)
    return compute_stats(db, habit_id)
