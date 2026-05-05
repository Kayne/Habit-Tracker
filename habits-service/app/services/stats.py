"""Wyliczanie statystyk nawyku: streak, completion rate."""
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.models import Habit, HabitLog
from app.schemas import HabitStats


def compute_stats(db: Session, habit_id) -> HabitStats:
    habit = db.query(Habit).filter(Habit.id == habit_id).first()
    frequency_type = habit.frequency_type if habit else "weekly"
    target = habit.target_per_frequency if habit else 7

    logs = (
        db.query(HabitLog)
        .filter(HabitLog.habit_id == habit_id)
        .order_by(HabitLog.logged_on.desc())
        .all()
    )

    total = len(logs)
    logged_dates = {log.logged_on for log in logs}
    last_logged = logs[0].logged_on if logs else None

    # Current streak — od dzisiaj wstecz, dopóki ciąg dzienny trwa.
    today = date.today()
    current_streak = 0
    d = today
    # Pozwól na "wczoraj" jako start (jeśli user jeszcze nie zalogował dzisiaj)
    if d not in logged_dates and (d - timedelta(days=1)) in logged_dates:
        d = d - timedelta(days=1)
    while d in logged_dates:
        current_streak += 1
        d = d - timedelta(days=1)

    # Longest streak
    longest = 0
    run = 0
    prev: date | None = None
    for d_sorted in sorted(logged_dates):
        if prev is not None and d_sorted == prev + timedelta(days=1):
            run += 1
        else:
            run = 1
        longest = max(longest, run)
        prev = d_sorted

    # Completion rate zależny od częstotliwości:
    #   daily   → dni zalogowane w ost. 7 dniach / 7
    #   weekly  → dni zalogowane w ost. 7 dniach / target_per_frequency
    #   monthly → dni zalogowane w ost. 30 dniach / target_per_frequency
    if frequency_type == "monthly":
        window = {today - timedelta(days=i) for i in range(30)}
        completed = len(window & logged_dates)
        completion_rate = completed / max(target, 1)
    elif frequency_type == "daily":
        last7 = {today - timedelta(days=i) for i in range(7)}
        completed7 = len(last7 & logged_dates)
        completion_rate = completed7 / 7.0
    else:  # weekly (domyślny)
        last7 = {today - timedelta(days=i) for i in range(7)}
        completed7 = len(last7 & logged_dates)
        completion_rate = completed7 / max(target, 1)

    # Zablokowanie wartości do przedziału [0.0, 1.0]
    completion_rate = min(1.0, completion_rate)

    return HabitStats(
        habit_id=habit_id,
        total_logs=total,
        current_streak_days=current_streak,
        longest_streak_days=longest,
        completion_rate_current_period=round(completion_rate, 3),
        last_logged_on=last_logged,
    )
