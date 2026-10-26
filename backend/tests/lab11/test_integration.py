from datetime import date
from decimal import Decimal

from sqlalchemy import select, func
from app.database.models import Recipe, RecipeIngredient, PreparationStep, MealPlan, ShoppingItem
from tests.lab11.conftest import DAY, EMAIL, recipe_payload, record


def test_IT_001_recipe_is_committed_to_sqlite(client, application, lab_user, lab_headers, record_property):
    payload = recipe_payload()
    response = client.post("/api/v1/recipes", headers=lab_headers, json=payload)
    assert response.status_code == 201
    with application.state.session_factory() as session:
        recipe = session.get(Recipe, response.json()["id"])
        assert recipe is not None and recipe.user_id == lab_user["id"]
        assert recipe.name == payload["name"] and recipe.user.email == EMAIL
        assert recipe.calories == 320 and recipe.servings == 2
        rows = session.scalars(select(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe.id).order_by(RecipeIngredient.position)).all()
        steps = session.scalars(select(PreparationStep).where(PreparationStep.recipe_id == recipe.id).order_by(PreparationStep.position)).all()
        assert len(rows) == 3 and all(row.user_id == lab_user["id"] for row in rows)
        assert [row.ingredient.name for row in rows] == ["Яйця", "Молоко", "Сіль"]
        assert [row.quantity for row in rows] == [Decimal(4), Decimal(100), None]
        assert [row.unit for row in rows] == ["шт", "мл", None]
        assert rows[2].note == "за смаком"
        assert [step.text for step in steps] == payload["preparation_steps"]
        record(record_property, "IT-001", f"POST {response.status_code}; SQLite: 1 рецепт, {len(rows)} зв’язки інгредієнтів, {len(steps)} кроки")


def test_IT_002_meal_plan_foreign_key_and_single_slot(client, application, lab_user, lab_headers, lab_recipe, record_property):
    body = {"date": DAY, "meal_type": "breakfast", "recipe_id": lab_recipe["id"]}
    response = client.put("/api/v1/meal-plans", headers=lab_headers, json=body | {"planned_servings": 0.5})
    assert response.status_code == 200
    plan_id = response.json()["id"]
    with application.state.session_factory() as session:
        slot = session.get(MealPlan, plan_id)
        assert slot.user_id == lab_user["id"] and slot.date == date(2026, 12, 28)
        assert slot.meal_type == "breakfast" and slot.planned_servings == 0.5
        assert slot.recipe_id == slot.recipe.id == lab_recipe["id"]
    replaced = client.put("/api/v1/meal-plans", headers=lab_headers, json=body | {"planned_servings": 2})
    assert replaced.status_code == 200 and replaced.json()["id"] == plan_id
    with application.state.session_factory() as session:
        count = session.scalar(select(func.count()).select_from(MealPlan).where(MealPlan.user_id == lab_user["id"], MealPlan.date == date(2026, 12, 28), MealPlan.meal_type == "breakfast"))
        assert count == 1 and session.get(MealPlan, plan_id).planned_servings == 2
    record(record_property, "IT-002", f"PUT {response.status_code}/{replaced.status_code}; SQLite: {count} слот, FK коректний, порції 0.5 → 2, id незмінний")


def test_IT_003_shopping_quantities_are_saved_in_sqlite(client, application, lab_user, lab_headers, lab_recipe, record_property):
    for meal, portions in [("breakfast", 1), ("lunch", 0.5)]:
        response = client.put("/api/v1/meal-plans", headers=lab_headers, json={"date": DAY, "meal_type": meal, "recipe_id": lab_recipe["id"], "planned_servings": portions})
        assert response.status_code == 200
    response = client.get("/api/v1/shopping-items", headers=lab_headers, params={"week_start": DAY})
    assert response.status_code == 200
    with application.state.session_factory() as session:
        rows = session.scalars(select(ShoppingItem).where(ShoppingItem.user_id == lab_user["id"], ShoppingItem.week_start == date(2026, 12, 28))).all()
        products = {row.ingredient_name: row for row in rows}
        assert len(rows) == len(products) == 3
        assert len({row.aggregation_key for row in rows}) == 3
        assert products["Яйця"].quantity == Decimal(3) and products["Яйця"].unit == "шт"
        assert products["Молоко"].quantity == Decimal(75) and products["Молоко"].unit == "мл"
        assert products["Сіль"].quantity is None and products["Сіль"].unit is None
        assert not any(row.is_manual or row.is_purchased for row in rows)
        assert {row.id for row in rows} == {row["id"] for row in response.json()}
        record(record_property, "IT-003", f"GET {response.status_code}; SQLite: {len(rows)} позиції; яйця {products['Яйця'].quantity} шт; молоко {products['Молоко'].quantity} мл; сіль NULL")
