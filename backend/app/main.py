from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.config import Settings
from app.core.errors import install_error_handlers
from app.core.security import Security
from app.database.session import create_database
from app.routers import auth, users, recipes, meal_plans, shopping, statistics


def create_app(settings: Settings | None = None) -> FastAPI:
    config = settings or Settings()
    engine, session_factory = create_database(config.database_url)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        yield
        engine.dispose()

    app = FastAPI(title="MealMate API", version="0.2.0", lifespan=lifespan,
        description="Етап 3: авторизація, рецепти, план, покупки та статистика. Калорійність рецептів — на одну порцію.")
    app.state.session_factory = session_factory
    app.state.engine = engine
    app.state.security = Security(config)
    install_error_handlers(app)
    app.include_router(auth.router, prefix="/api/v1")
    app.include_router(users.router, prefix="/api/v1")
    for router in (recipes.router, meal_plans.router, shopping.router, statistics.router):
        app.include_router(router, prefix="/api/v1")
    # Таблиці створює лише Alembic, не запуск API.
    return app
