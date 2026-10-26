from datetime import date
from uuid import uuid4

from alembic import command
import pytest
from sqlalchemy import delete, inspect, select, text
from sqlalchemy.exc import IntegrityError

from app.database.models import User, Recipe, Ingredient, RecipeIngredient, PreparationStep, MealPlan, ShoppingItem
from tests.conftest import migration_config, register


def make_recipe(user_id):
    return Recipe(user_id=user_id, name="Омлет", category="breakfast", preparation_minutes=15, calories=320, servings=2)


def seed(application):
    with application.state.session_factory() as session:
        users = [User(name="Один", email="one@example.com", password_hash="test-hash"), User(name="Два", email="two@example.com", password_hash="test-hash")]
        session.add_all(users)
        session.flush()
        recipe = make_recipe(users[0].id)
        ingredient = Ingredient(user_id=users[1].id, name="Яйця", normalized_name="яйця")
        session.add_all([recipe, ingredient])
        session.commit()
        return users[0].id, users[1].id, recipe.id, ingredient.id


def test_migrations_and_foreign_keys(application, settings):
    expected = {"users", "recipes", "ingredients", "recipe_ingredients", "preparation_steps", "meal_plans", "shopping_items", "alembic_version"}
    assert set(inspect(application.state.engine).get_table_names()) == expected
    with application.state.engine.connect() as first, application.state.engine.connect() as second:
        assert first.scalar(text("PRAGMA foreign_keys")) == second.scalar(text("PRAGMA foreign_keys")) == 1
    command.check(migration_config(settings.database_url))
    command.downgrade(migration_config(settings.database_url), "base")
    assert set(inspect(application.state.engine).get_table_names()) == {"alembic_version"}
    command.upgrade(migration_config(settings.database_url), "head")
    assert set(inspect(application.state.engine).get_table_names()) == expected


@pytest.mark.parametrize("kind", ["meal", "ingredient", "step", "missing_recipe"])
def test_cross_user_and_missing_references_rejected(application, kind):
    first, second, recipe_id, ingredient_id = seed(application)
    with application.state.session_factory() as session:
        if kind == "meal":
            row = MealPlan(user_id=second, date=date(2026, 10, 26), meal_type="breakfast", recipe_id=recipe_id)
        elif kind == "ingredient":
            row = RecipeIngredient(user_id=first, recipe_id=recipe_id, ingredient_id=ingredient_id, quantity=1, unit="шт", position=1)
        elif kind == "step":
            row = PreparationStep(user_id=second, recipe_id=recipe_id, position=1, text="Готувати")
        else:
            row = MealPlan(user_id=first, date=date(2026, 10, 26), meal_type="lunch", recipe_id=str(uuid4()))
        session.add(row)
        with pytest.raises(IntegrityError): session.commit()


def test_slots_steps_constraints_and_recipe_cascade(application):
    owner, _, recipe_id, _ = seed(application)
    with application.state.session_factory() as session:
        ingredient = Ingredient(user_id=owner, name="Сіль", normalized_name="сіль")
        session.add(ingredient)
        session.flush()
        session.add_all([
            RecipeIngredient(user_id=owner, recipe_id=recipe_id, ingredient_id=ingredient.id, quantity=None, unit=None, note="за смаком", position=1),
            PreparationStep(user_id=owner, recipe_id=recipe_id, position=1, text="Приготувати"),
            MealPlan(user_id=owner, recipe_id=recipe_id, date=date(2026, 10, 26), meal_type="breakfast", planned_servings=0.5),
        ])
        session.commit()
        assert session.scalar(select(Recipe)).ingredients[0].ingredient.name == "Сіль"
        session.add(MealPlan(user_id=owner, recipe_id=recipe_id, date=date(2026, 10, 26), meal_type="breakfast"))
        with pytest.raises(IntegrityError): session.commit()
        session.rollback()
        session.execute(delete(Recipe).where(Recipe.id == recipe_id))
        session.commit()
        assert session.scalars(select(MealPlan)).all() == []
        assert session.scalars(select(PreparationStep)).all() == []
        assert session.scalars(select(RecipeIngredient)).all() == []


@pytest.mark.parametrize("kind", ["goal", "calories", "servings", "planned_servings", "taste", "shopping"])
def test_database_checks(application, kind):
    owner, _, recipe_id, _ = seed(application)
    with application.state.session_factory() as session:
        match kind:
            case "goal": row = User(name="Bad", email="bad@example.com", password_hash="test", daily_calorie_goal=0)
            case "calories": row = make_recipe(owner); row.calories = -1
            case "servings": row = make_recipe(owner); row.servings = 0
            case "planned_servings": row = MealPlan(user_id=owner, recipe_id=recipe_id, date=date(2026, 10, 26), meal_type="breakfast", planned_servings=0)
            case "taste":
                ingredient = Ingredient(user_id=owner, name="Сіль", normalized_name="сіль")
                session.add(ingredient); session.flush()
                row = RecipeIngredient(user_id=owner, recipe_id=recipe_id, ingredient_id=ingredient.id, quantity=None, unit=None, note=None, position=1)
            case "shopping": row = ShoppingItem(user_id=owner, week_start=date(2026, 10, 26), ingredient_name="Молоко", quantity=1, unit="invalid", category="dairy", is_manual=True)
        session.add(row)
        with pytest.raises(IntegrityError): session.commit()


def test_shopping_weeks_and_manual_items_are_isolated(application):
    owner, other, _, _ = seed(application)
    def row(user, week, manual=False):
        return ShoppingItem(user_id=user, week_start=week, ingredient_name="Яйця", quantity=1, unit="шт", category="other", is_manual=manual, aggregation_key=None if manual else "яйця|шт")
    monday = date(2026, 10, 26)
    with application.state.session_factory() as session:
        session.add_all([row(owner,monday),row(other,monday),row(owner,date(2026,11,2)),row(owner,monday,True),row(owner,monday,True)])
        session.commit()
        session.add(row(owner,monday))
        with pytest.raises(IntegrityError): session.commit()
