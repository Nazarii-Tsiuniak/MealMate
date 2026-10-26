from datetime import date
from pydantic import BaseModel


class DailyStatistics(BaseModel):
    date: date
    meals: dict[str, float | None]
    known_calories: float
    total_calories: float | None
    daily_goal: int
    goal_progress_percent: float
    progress_fraction: float
    remaining_calories: float
    is_complete: bool


class ChartDay(BaseModel):
    date: date
    calories: float
    is_complete: bool


class WeeklyStatistics(BaseModel):
    start_date: date
    end_date: date
    days: list[DailyStatistics]
    chart: list[ChartDay]
    average_calories: float
    is_complete: bool
