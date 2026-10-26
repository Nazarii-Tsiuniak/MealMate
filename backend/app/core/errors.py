import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException

logger = logging.getLogger(__name__)


class DomainError(Exception):
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def domain_error(request: Request, exc: DomainError):
        headers = {"WWW-Authenticate": "Bearer"} if exc.status_code == 401 else None
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.message}, headers=headers)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, exc: RequestValidationError):
        # Не віддаємо input/ctx: вони можуть містити пароль або внутрішній об’єкт.
        errors = [{"loc": list(e["loc"]), "type": e["type"], "msg": "Перевірте значення поля"} for e in exc.errors()]
        status = 400 if any(e["type"] == "json_invalid" for e in exc.errors()) else 422
        return JSONResponse(status_code=status, content={"detail": errors})

    @app.exception_handler(HTTPException)
    async def http_error(request: Request, exc: HTTPException):
        message = {401: "Потрібна авторизація", 404: "Ресурс не знайдено", 405: "Метод не підтримується"}.get(exc.status_code, "Запит не може бути виконано")
        return JSONResponse(status_code=exc.status_code, content={"detail": message}, headers=exc.headers)

    @app.exception_handler(Exception)
    async def internal_error(request: Request, exc: Exception):
        # Не журналюємо тіло запиту, пароль або JWT.
        logger.error("Внутрішня помилка API: %s", type(exc).__name__)
        return JSONResponse(status_code=500, content={"detail": "Внутрішня помилка сервера"})
