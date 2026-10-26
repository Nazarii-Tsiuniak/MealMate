from datetime import date as Date
from typing import Annotated
from uuid import UUID
from fastapi import APIRouter, Depends, Response
from app.database.models import User
from app.dependencies import current_user, get_shopping_service
from app.schemas.shopping import ShoppingInput, ShoppingPatch, ShoppingRead
from app.services.shopping_service import ShoppingService

router = APIRouter(prefix="/shopping-items", tags=["Покупки"])
CurrentUser = Annotated[User, Depends(current_user)]
Service = Annotated[ShoppingService, Depends(get_shopping_service)]


@router.get("", response_model=list[ShoppingRead], summary="Покупки вибраного тижня")
def items(user: CurrentUser, service: Service, week_start: Date | None = None):
    return service.list(user.id, week_start or Date.today())


@router.post("", response_model=ShoppingRead, status_code=201, summary="Додати ручний продукт")
def create(data: ShoppingInput, user: CurrentUser, service: Service):
    return service.create(user.id, data)


@router.patch("/{item_id}", response_model=ShoppingRead, summary="Позначити придбаним або змінити ручний продукт")
def patch(item_id: UUID, data: ShoppingPatch, user: CurrentUser, service: Service):
    return service.patch(user.id, str(item_id), data)


@router.delete("/{item_id}", status_code=204, summary="Видалити лише ручний продукт")
def delete(item_id: UUID, user: CurrentUser, service: Service):
    service.delete(user.id, str(item_id))
    return Response(status_code=204)
