"""Явне, атомарне наповнення наявного акаунта без зміни його рецептів."""
import argparse
from dataclasses import dataclass
import os
from uuid import NAMESPACE_URL, UUID, uuid5

from dotenv import dotenv_values
from pydantic import EmailStr, TypeAdapter, ValidationError
from sqlalchemy import inspect

from app.core.config import BACKEND_ROOT
from app.database.models import Recipe
from app.database.session import create_database
from app.repositories.recipe_repository import RecipeRepository
from app.repositories.user_repository import UserRepository
from app.services.domain_utils import normalize_name
from scripts.demo_recipes import RECIPES


@dataclass(frozen=True)
class SeedResult:
    created: int
    skipped: int
    dry_run: bool


def seed_id(user_id: str, key: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"mealmate/demo-recipes/v1/{UUID(user_id)}/{key}"))


def seed_recipes(session, user_email: str, *, dry_run: bool = False) -> SeedResult:
    email = str(TypeAdapter(EmailStr).validate_python(user_email.strip())).casefold()
    # Усі рецепти валідуються до будь-якого запису.
    prepared = [(entry, entry.payload()) for entry in RECIPES]
    repository = RecipeRepository(session)
    created = skipped = 0
    with repository.transaction():
        user = UserRepository(session).by_email(email)
        if user is None:
            raise ValueError("Користувача не знайдено. Спочатку зареєструйте свій акаунт у MealMate")
        existing_names = {normalize_name(recipe.name) for recipe in repository.all(user.id)}
        for entry, payload in prepared:
            recipe_id = seed_id(user.id, entry.key)
            existing = session.get(Recipe, recipe_id)
            if existing is not None:
                if existing.user_id != user.id:
                    raise ValueError("Конфлікт ідентифікатора; жодні дані не змінено")
                skipped += 1
                continue
            if normalize_name(payload.name) in existing_names:
                # Користувацький рецепт з такою назвою ніколи не перезаписуємо.
                skipped += 1
                continue
            if not dry_run:
                recipe = Recipe(id=recipe_id, user_id=user.id,
                    **payload.model_dump(exclude={"ingredients", "preparation_steps"}))
                session.add(recipe)
                # Наявний репозиторій зберігає зв’язки, інгредієнти й порядок кроків.
                repository.save(user.id, payload, normalize_name, recipe)
            existing_names.add(normalize_name(payload.name))
            created += 1
    return SeedResult(created, skipped, dry_run)


def database_url() -> str:
    return os.getenv("MEALMATE_DATABASE_URL") or dotenv_values(BACKEND_ROOT / ".env").get("MEALMATE_DATABASE_URL") or "sqlite:///./data/mealmate.db"


def main() -> int:
    parser = argparse.ArgumentParser(description="Додати 10 демонстраційних рецептів лише до вказаного наявного акаунта")
    parser.add_argument("--user-email", required=True, help="Email вашого наявного тестового акаунта")
    parser.add_argument("--dry-run", action="store_true", help="Перевірити, що буде додано, без запису")
    args = parser.parse_args()
    engine, factory = create_database(database_url())
    try:
        if not inspect(engine).has_table("users"):
            raise ValueError("Спочатку виконайте python -m alembic upgrade head")
        with factory() as session:
            result = seed_recipes(session, args.user_email, dry_run=args.dry_run)
        prefix = "Перевірка без запису. Буде додано" if result.dry_run else "Додано"
        print(f"{prefix}: {result.created}; пропущено наявних: {result.skipped}")
        for entry in RECIPES:
            data = entry.payload()
            print(f"- {data.name}: {data.servings} порц., {data.preparation_minutes} хв, приблизно {data.calories} ккал/порція")
        return 0
    except (ValueError, ValidationError) as error:
        print(f"Наповнення не виконано: {error}")
        return 1
    finally:
        engine.dispose()


if __name__ == "__main__":
    raise SystemExit(main())
