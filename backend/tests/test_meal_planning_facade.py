from contextlib import contextmanager
from datetime import date
from types import SimpleNamespace
from unittest.mock import Mock, patch
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.database.models import MealPlan, Recipe, ShoppingItem
from app.schemas.meal_plan import MealPlanInput
from app.services.domain_utils import normalize_name
from app.services.meal_planning_facade import MealPlanningFacade
from tests.conftest import auth, register
from tests.lab11.conftest import DAY, recipe_payload


@pytest.fixture
def coordination():
    events = []
    recipes, plans, shopping = Mock(), Mock(), Mock()

    @contextmanager
    def transaction():
        events.append("begin")
        yield
        events.append("commit")

    recipes.repository.transaction.side_effect = transaction
    plans.repository.transaction.side_effect = transaction
    recipes.find.side_effect = lambda *args: events.append("owner") or "recipe"
    plans.repository.recipe_dates.side_effect = lambda *args: events.append("weeks") or [date(2026, 12, 28), date(2026, 12, 30)]
    recipes.repository.save.side_effect = lambda *args: events.append("save") or "recipe"
    recipes.repository.delete.side_effect = lambda *args: events.append("delete")
    plans.repository.delete.side_effect = lambda *args: events.append("delete")
    recipes.read.side_effect = lambda *args: events.append("serialize") or "result"
    shopping.synchronize.side_effect = lambda *args: events.append("sync")
    return MealPlanningFacade(recipes, plans, shopping), events


def test_facade_update_coordinates_one_transaction_and_unique_weeks(coordination):
    facade, events = coordination
    data = object()
    assert facade.save_recipe("user", data, "id") == "result"
    assert events == ["begin", "owner", "weeks", "save", "sync", "serialize", "commit"]
    facade.recipes.repository.save.assert_called_once_with("user", data, normalize_name, "recipe")
    facade.shopping.synchronize.assert_called_once_with("user", {date(2026, 12, 28)})


def test_facade_create_does_not_query_plan_dates(coordination):
    facade, events = coordination
    assert facade.save_recipe("user", object()) == "result"
    assert events == ["begin", "save", "sync", "serialize", "commit"]
    facade.recipes.find.assert_not_called()
    facade.plans.repository.recipe_dates.assert_not_called()
    facade.shopping.synchronize.assert_called_once_with("user", set())


def test_facade_delete_recipe_checks_owner_before_delete_and_sync(coordination):
    facade, events = coordination
    facade.delete_recipe("user", "id")
    assert events == ["begin", "owner", "weeks", "delete", "sync", "commit"]
    facade.shopping.synchronize.assert_called_once_with("user", {date(2026, 12, 28)})


def test_facade_assign_preserves_portions_and_serializes_before_commit(coordination):
    facade, events = coordination
    data = MealPlanInput(date=date(2026, 12, 30), meal_type="breakfast", recipe_id=uuid4(), planned_servings=0.5)
    slot = SimpleNamespace(id=uuid4(), date=data.date, meal_type=data.meal_type, recipe_id=data.recipe_id, planned_servings=0.5)
    facade.plans.repository.assign.side_effect = lambda *args: events.append("assign") or slot
    result = facade.assign_meal("user", data)
    assert result.planned_servings == 0.5 and result.id == slot.id
    assert events == ["begin", "owner", "assign", "sync", "commit"]
    facade.recipes.find.assert_called_once_with("user", str(data.recipe_id))
    facade.shopping.synchronize.assert_called_once_with("user", {date(2026, 12, 28)})


def test_facade_delete_meal_syncs_original_week(coordination):
    facade, events = coordination
    slot = SimpleNamespace(date=date(2027, 1, 3))
    facade.plans.find.side_effect = lambda *args: events.append("owner") or slot
    facade.delete_meal("user", "id")
    assert events == ["begin", "owner", "delete", "sync", "commit"]
    facade.plans.repository.delete.assert_called_once_with(slot)
    facade.shopping.synchronize.assert_called_once_with("user", {date(2026, 12, 28)})


@pytest.fixture
def scenario(client):
    registered = register(client)
    assert registered.status_code == 201
    headers = auth(client)
    response = client.post("/api/v1/recipes", headers=headers, json=recipe_payload())
    assert response.status_code == 201
    recipe = response.json()
    body = {"date": DAY, "meal_type": "breakfast", "recipe_id": recipe["id"], "planned_servings": 0.5}
    response = client.put("/api/v1/meal-plans", headers=headers, json=body)
    assert response.status_code == 200
    return headers, recipe, response.json(), body


def database_state(application):
    with application.state.session_factory() as session:
        return {
            "recipes": [(r.id, r.name, r.servings) for r in session.scalars(select(Recipe).order_by(Recipe.id))],
            "plans": [(r.id, r.recipe_id, r.planned_servings) for r in session.scalars(select(MealPlan).order_by(MealPlan.id))],
            "shopping": [(r.id, r.quantity, r.is_purchased) for r in session.scalars(select(ShoppingItem).order_by(ShoppingItem.id))],
        }


def mutate(client, headers, recipe, plan, body, operation):
    if operation == "create":
        return client.post("/api/v1/recipes", headers=headers, json=recipe_payload(name="Не зберігати"))
    if operation == "update":
        return client.put("/api/v1/recipes/" + recipe["id"], headers=headers, json=recipe_payload(name="Не зберігати"))
    if operation == "delete_recipe":
        return client.delete("/api/v1/recipes/" + recipe["id"], headers=headers)
    if operation == "assign":
        return client.put("/api/v1/meal-plans", headers=headers, json=body | {"planned_servings": 2})
    return client.delete("/api/v1/meal-plans/" + plan["id"], headers=headers)


@pytest.mark.parametrize("operation", ["create", "update", "delete_recipe", "assign", "delete_meal"])
def test_facade_sync_failure_rolls_back_every_write(client, application, scenario, operation):
    headers, recipe, plan, body = scenario
    before = database_state(application)
    with patch("app.services.shopping_service.ShoppingService.synchronize", side_effect=RuntimeError("injected")) as sync:
        response = mutate(client, headers, recipe, plan, body, operation)
        sync.assert_called_once()
    assert response.status_code == 500
    assert "injected" not in response.text
    assert database_state(application) == before


@pytest.mark.parametrize("operation", ["update", "delete_recipe", "assign", "delete_meal"])
def test_facade_denies_foreign_writes_before_synchronization(client, application, scenario, operation):
    _, recipe, plan, body = scenario
    assert register(client, email="other@example.com").status_code == 201
    headers = auth(client, "other@example.com")
    before = database_state(application)
    with patch("app.services.shopping_service.ShoppingService.synchronize") as sync:
        response = mutate(client, headers, recipe, plan, body, operation)
        sync.assert_not_called()
    assert response.status_code == 404
    assert database_state(application) == before


def test_facade_invalid_input_does_not_enter_transaction(client, application, scenario):
    headers, recipe, plan, body = scenario
    before = database_state(application)
    with patch("app.repositories.base.Repository.transaction") as transaction:
        assert client.put("/api/v1/meal-plans", headers=headers, json=body | {"planned_servings": 0}).status_code == 422
        assert client.post("/api/v1/recipes", headers=headers, json=recipe_payload(servings=0)).status_code == 422
        transaction.assert_not_called()
    assert database_state(application) == before


def test_facade_recipe_edit_syncs_all_affected_weeks_and_keeps_manual_items(client, scenario):
    headers, recipe, _, body = scenario
    next_week = "2027-01-04"
    assert client.put("/api/v1/meal-plans", headers=headers, json=body | {"date": next_week, "planned_servings": 2}).status_code == 200
    manual = client.post("/api/v1/shopping-items", headers=headers, json={"week_start": DAY, "ingredient_name": "Чай", "quantity": 1, "unit": "шт"})
    assert manual.status_code == 201
    automatic = client.get("/api/v1/shopping-items", headers=headers, params={"week_start": DAY}).json()
    eggs = next(row for row in automatic if row["ingredient_name"] == "Яйця")
    assert client.patch("/api/v1/shopping-items/" + eggs["id"], headers=headers, json={"is_purchased": True}).status_code == 200
    payload = recipe_payload(calories=400)
    payload["ingredients"][0]["quantity"] = 8
    assert client.put("/api/v1/recipes/" + recipe["id"], headers=headers, json=payload).status_code == 200
    for week, expected in [(DAY, 2), (next_week, 8)]:
        items = client.get("/api/v1/shopping-items", headers=headers, params={"week_start": week}).json()
        eggs = next(row for row in items if row["ingredient_name"] == "Яйця")
        assert eggs["quantity"] == expected and not eggs["is_purchased"]
        assert len({row["id"] for row in items}) == len(items)
    items = client.get("/api/v1/shopping-items", headers=headers, params={"week_start": DAY}).json()
    assert manual.json() in items
    daily = client.get("/api/v1/statistics/daily", headers=headers, params={"date": DAY}).json()
    assert daily["total_calories"] == 200
    weekly = client.get("/api/v1/statistics/weekly", headers=headers, params={"start_date": DAY}).json()
    assert weekly["average_calories"] == pytest.approx(200 / 7)
