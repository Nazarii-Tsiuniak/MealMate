from datetime import date as Date
from typing import Annotated
from fastapi import APIRouter, Depends
from app.database.models import User
from app.dependencies import current_user, get_nutrition_service
from app.schemas.statistics import DailyStatistics, WeeklyStatistics
from app.services.nutrition_service import NutritionService

router = APIRouter(prefix="/statistics", tags=["Калорії"])
CurrentUser = Annotated[User, Depends(current_user)]
Service = Annotated[NutritionService, Depends(get_nutrition_service)]


@router.get("/daily", response_model=DailyStatistics, summary="Калорії вибраного дня")
def daily(date: Date, user: CurrentUser, service: Service):
    return service.daily(user, date)


@router.get("/weekly", response_model=WeeklyStatistics, summary="Статистика за сім днів тижня")
def weekly(start_date: Date, user: CurrentUser, service: Service):
    return service.weekly(user, start_date)
