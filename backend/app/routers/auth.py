from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.dependencies import get_auth_service
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse
from app.schemas.user import UserRead
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Авторизація"])


@router.post("/register", response_model=UserRead, status_code=201, summary="Реєстрація користувача")
def register(data: RegisterRequest, service: Annotated[AuthService, Depends(get_auth_service)]):
    return service.register(data)


@router.post("/login", response_model=TokenResponse, summary="Вхід та отримання JWT")
def login(data: LoginRequest, response: Response, service: Annotated[AuthService, Depends(get_auth_service)]):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    return service.login(data)
