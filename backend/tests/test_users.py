from fastapi.testclient import TestClient
import pytest
from sqlalchemy.exc import OperationalError

from app.dependencies import get_user_service
from app.main import create_app
from tests.conftest import auth, login, register


def test_profile_updates_are_isolated(client):
    first = register(client).json()
    second = register(client, email="other@example.com", name="Інший").json()
    headers = auth(client)
    response = client.patch("/api/v1/users/me", headers=headers,
        json={"name": "Назарій", "daily_calorie_goal": 1800, "email": "new@example.com"})
    assert response.status_code == 200
    assert response.json() == first | {"name": "Назарій", "daily_calorie_goal": 1800, "email": "new@example.com"}
    assert client.get("/api/v1/users/me", headers=auth(client, "other@example.com")).json() == second
    assert login(client).status_code == 401
    assert login(client, email="new@example.com").status_code == 200
    # Чинний JWT ідентифікує користувача за id, не старим email.
    assert client.get("/api/v1/users/me", headers=headers).json()["email"] == "new@example.com"


@pytest.mark.parametrize("goal", [0, -1, 100001, 1.5, "2000", True, None])
def test_invalid_goal(client, goal):
    register(client)
    headers = auth(client)
    assert client.patch("/api/v1/users/me", headers=headers, json={"daily_calorie_goal": goal}).status_code == 422
    assert client.get("/api/v1/users/me", headers=headers).json()["daily_calorie_goal"] == 2000


@pytest.mark.parametrize("payload,status", [({}, 400), ({"name": ""}, 422), ({"name": None}, 422), ({"email": None}, 422), ({"email": "bad"}, 422), ({"id": "other"}, 422), ({"password_hash": "injected"}, 422)])
def test_invalid_profile_update(client, payload, status):
    register(client)
    assert client.patch("/api/v1/users/me", headers=auth(client), json=payload).status_code == status


def test_conflicting_email_does_not_partially_update(client):
    register(client)
    register(client, email="other@example.com")
    headers = auth(client)
    response = client.patch("/api/v1/users/me", headers=headers, json={"email": "OTHER@example.com", "daily_calorie_goal": 1500})
    assert response.status_code == 409
    assert client.get("/api/v1/users/me", headers=headers).json()["daily_calorie_goal"] == 2000


def test_sqlite_survives_new_application_and_engine(client, settings):
    original = register(client).json()
    headers = auth(client)
    client.patch("/api/v1/users/me", headers=headers, json={"daily_calorie_goal": 1750})
    restarted = create_app(settings)
    with TestClient(restarted) as new_client:
        response = new_client.get("/api/v1/users/me", headers=headers)
        assert response.status_code == 200
        assert response.json()["id"] == original["id"]
        assert response.json()["daily_calorie_goal"] == 1750
        assert login(new_client).status_code == 200


def test_internal_error_does_not_leak_details(client, application):
    def broken_service():
        raise OperationalError("private SQL", {}, Exception("password and secret"))
    application.dependency_overrides[get_user_service] = broken_service
    response = client.get("/api/v1/users/me", headers={"Authorization": "Bearer any"})
    assert response.status_code == 500
    assert response.json() == {"detail": "Внутрішня помилка сервера"}
