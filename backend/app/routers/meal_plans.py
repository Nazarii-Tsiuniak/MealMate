from datetime import date as Date
from typing import Annotated
from uuid import UUID
from fastapi import APIRouter, Depends, Response
from app.database.models import User
from app.dependencies import current_user, get_meal_plan_service
from app.schemas.meal_plan import MealPlanInput, MealPlanRead
from app.services.meal_plan_service import MealPlanService
from app.services.domain_utils import monday, shift

router = APIRouter(prefix="/meal-plans", tags=["План харчування"])
CurrentUser = Annotated[User, Depends(current_user)]
Service = Annotated[MealPlanService, Depends(get_meal_plan_service)]


@router.get("", response_model=list[MealPlanRead], summary="План за включним діапазоном дат")
def plans(user: CurrentUser, service: Service, start_date: Date | None = None, end_date: Date | None = None):
    start = start_date or (shift(end_date, -6) if end_date else monday(Date.today()))
    end = end_date or shift(start, 6)
    return service.list(user.id, start, end)


@router.put("", response_model=MealPlanRead, summary="Додати або замінити страву в одному слоті")
def assign(data: MealPlanInput, user: CurrentUser, service: Service):
    return service.assign(user.id, data)


@router.delete("/{plan_id}", status_code=204, summary="Прибрати страву з плану")
def delete(plan_id: UUID, user: CurrentUser, service: Service):
    service.delete(user.id, str(plan_id))
    return Response(status_code=204)
