import pytest
from tests.conftest import register, auth

EMAIL = "lab11@example.com"
PASSWORD = "Test-password-123"
DAY = "2026-12-28"


def recipe_payload(**changes):
    return {
        "name": "Омлет для ЛР11", "description": "Синтетичний тестовий рецепт",
        "category": "breakfast", "preparation_minutes": 15, "calories": 320,
        "servings": 2,
        "ingredients": [
            {"name": "Яйця", "quantity": 4, "unit": "шт"},
            {"name": "Молоко", "quantity": 100, "unit": "мл"},
            {"name": "Сіль", "quantity": None, "unit": None, "note": "за смаком"},
        ],
        "preparation_steps": ["Збити яйця з молоком", "Приготувати омлет"],
    } | changes


@pytest.fixture
def lab_user(client):
    response = register(client, email=EMAIL, name="Лабораторія 11")
    assert response.status_code == 201
    return response.json()


@pytest.fixture
def lab_headers(client, lab_user):
    return auth(client, EMAIL)


@pytest.fixture
def lab_recipe(client, lab_headers):
    response = client.post("/api/v1/recipes", headers=lab_headers, json=recipe_payload())
    assert response.status_code == 201
    return response.json()


def record(record_property, case_id, message):
    record_property("case_id", case_id)
    record_property("actual_result", message)
