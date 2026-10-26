from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.errors import DomainError
from app.core.security import Security
from app.database.models import User
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService
from app.services.user_service import UserService

bearer = HTTPBearer(auto_error=False)


def get_session(request: Request):
    with request.app.state.session_factory() as session:
        yield session


def get_security(request: Request) -> Security:
    return request.app.state.security


def get_users(session: Annotated[Session, Depends(get_session)]) -> UserRepository:
    return UserRepository(session)


def get_auth_service(users: Annotated[UserRepository, Depends(get_users)], security: Annotated[Security, Depends(get_security)]) -> AuthService:
    return AuthService(users, security)


def get_user_service(users: Annotated[UserRepository, Depends(get_users)], security: Annotated[Security, Depends(get_security)]) -> UserService:
    return UserService(users, security)


def current_user(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)], service: Annotated[UserService, Depends(get_user_service)]) -> User:
    if credentials is None:
        raise DomainError(401, "Потрібна авторизація")
    return service.authenticate(credentials.credentials)


# Предметні сервіси мають спільні репозиторії та одну транзакцію на запит.
def get_domain_repositories(session: Annotated[Session, Depends(get_session)]):
    from app.repositories.recipe_repository import RecipeRepository
    from app.repositories.meal_plan_repository import MealPlanRepository
    from app.repositories.shopping_repository import ShoppingRepository
    return RecipeRepository(session), MealPlanRepository(session), ShoppingRepository(session)


def get_shopping_service(repositories=Depends(get_domain_repositories)):
    from app.services.shopping_service import ShoppingService
    _, plans, shopping = repositories
    return ShoppingService(shopping, plans)


def get_recipe_service(repositories=Depends(get_domain_repositories), shopping=Depends(get_shopping_service)):
    from app.services.recipe_service import RecipeService
    recipes, plans, _ = repositories
    return RecipeService(recipes, plans, shopping)


def get_meal_plan_service(repositories=Depends(get_domain_repositories), shopping=Depends(get_shopping_service)):
    from app.services.meal_plan_service import MealPlanService
    recipes, plans, _ = repositories
    return MealPlanService(plans, recipes, shopping)


def get_nutrition_service(repositories=Depends(get_domain_repositories)):
    from app.services.nutrition_service import NutritionService
    return NutritionService(repositories[1])
