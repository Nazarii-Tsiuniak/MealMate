from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.database.models import User
from app.dependencies import current_user, get_user_service
from app.schemas.user import UserRead, UserUpdate
from app.services.user_service import UserService

router = APIRouter(prefix="/users", tags=["Профіль"])


@router.get("/me", response_model=UserRead, summary="Мій профіль")
def profile(response: Response, user: Annotated[User, Depends(current_user)], service: Annotated[UserService, Depends(get_user_service)]):
    response.headers["Cache-Control"] = "no-store"
    return service.profile(user)


@router.patch("/me", response_model=UserRead, summary="Оновити профіль і денну ціль")
def update_profile(data: UserUpdate, response: Response, user: Annotated[User, Depends(current_user)], service: Annotated[UserService, Depends(get_user_service)]):
    response.headers["Cache-Control"] = "no-store"
    return service.update_profile(user, data)
