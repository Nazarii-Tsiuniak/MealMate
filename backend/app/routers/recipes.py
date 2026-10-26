from typing import Annotated
from uuid import UUID
from fastapi import APIRouter, Depends, Query, Response
from app.database.models import User
from app.dependencies import current_user, get_recipe_service
from app.schemas.recipe import Category, RecipeInput, RecipeRead
from app.services.recipe_service import RecipeService

router = APIRouter(prefix="/recipes", tags=["Рецепти"])
CurrentUser = Annotated[User, Depends(current_user)]
Service = Annotated[RecipeService, Depends(get_recipe_service)]


@router.get("", response_model=list[RecipeRead], summary="Мої рецепти: пошук і категорія")
def recipes(user: CurrentUser, service: Service,
        search: Annotated[str | None, Query(max_length=200)] = None, category: Category | None = None):
    return service.list(user.id, search, category)


@router.get("/{recipe_id}", response_model=RecipeRead, summary="Деталі мого рецепта")
def details(recipe_id: UUID, user: CurrentUser, service: Service):
    return service.details(user.id, str(recipe_id))


@router.post("", response_model=RecipeRead, status_code=201, summary="Створити рецепт")
def create(data: RecipeInput, user: CurrentUser, service: Service):
    return service.save(user.id, data)


@router.put("/{recipe_id}", response_model=RecipeRead, summary="Повністю оновити рецепт")
def update(recipe_id: UUID, data: RecipeInput, user: CurrentUser, service: Service):
    return service.save(user.id, data, str(recipe_id))


@router.delete("/{recipe_id}", status_code=204, summary="Видалити рецепт і його записи плану")
def delete(recipe_id: UUID, user: CurrentUser, service: Service):
    service.delete(user.id, str(recipe_id))
    return Response(status_code=204)
