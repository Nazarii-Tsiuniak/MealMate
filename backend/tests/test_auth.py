from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
import pytest
from sqlalchemy import select

from app.database.models import User
from tests.conftest import auth, login, register


def test_register_hash_and_login(client, application):
    response = register(client, email="NAZAR@Example.COM", name="  Назар  ")
    assert response.status_code == 201
    data = response.json()
    assert data == {"id": data["id"], "email": "nazar@example.com", "name": "Назар", "daily_calorie_goal": 2000}
    with application.state.session_factory() as session:
        user = session.scalar(select(User))
        assert user.password_hash.startswith("$argon2id$")
        assert user.password_hash != "Test-password-123"
        assert application.state.security.verify_password("Test-password-123", user.password_hash)
    response = login(client, email="NAZAR@example.com")
    assert response.status_code == 200
    assert response.json()["token_type"] == "bearer"
    assert response.json()["expires_in"] == 1800
    assert response.headers["Cache-Control"] == "no-store"
    assert "password" not in response.text
    response = client.get("/api/v1/users/me", headers=auth(client))
    assert response.status_code == 200
    assert response.json() == data


def test_duplicate_email_case_insensitive(client):
    assert register(client).status_code == 201
    assert register(client, email="NAZAR@EXAMPLE.COM").status_code == 409


def test_wrong_password_and_unknown_user_are_indistinguishable(client):
    register(client)
    wrong = login(client, password="Wrong-password")
    unknown = login(client, email="absent@example.com")
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json()
    assert wrong.headers["WWW-Authenticate"] == "Bearer"


@pytest.mark.parametrize("path,method", [("/api/v1/users/me", "get"), ("/api/v1/users/me", "patch")])
def test_missing_token(client, path, method):
    response = getattr(client, method)(path)
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"


@pytest.mark.parametrize("header", ["Bearer invalid", "Basic abc", "Bearer", "Bearer a.b.c"])
def test_malformed_token(client, header):
    assert client.get("/api/v1/users/me", headers={"Authorization": header}).status_code == 401


@pytest.mark.parametrize("change", ["expired", "signature", "issuer", "audience", "missing_exp", "future", "subject", "algorithm", "missing_user"])
def test_jwt_validation(client, application, change):
    user_id = register(client).json()["id"]
    security = application.state.security
    now = datetime.now(timezone.utc)
    payload = {"sub": user_id, "iat": now, "exp": now + timedelta(minutes=10), "jti": str(uuid4()),
        "iss": security.settings.jwt_issuer, "aud": security.settings.jwt_audience}
    key = security.settings.jwt_secret.get_secret_value()
    algorithm = "HS256"
    match change:
        case "expired": payload["exp"] = now - timedelta(seconds=1)
        case "signature": key = "unrelated-key-for-negative-test-1234567890"
        case "issuer": payload["iss"] = "wrong"
        case "audience": payload["aud"] = "wrong"
        case "missing_exp": del payload["exp"]
        case "future": payload["iat"] = now + timedelta(days=1)
        case "subject": payload["sub"] = "not-a-uuid"
        case "missing_user": payload["sub"] = str(uuid4())
        case "algorithm": algorithm = "HS384"
    token = jwt.encode(payload, key, algorithm=algorithm)
    assert client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


@pytest.mark.parametrize("changes", [
    {"email": "invalid"}, {"name": "  "}, {"password": "q7Z!x"},
    {"password": " " * 8}, {"password": "x" * 129}, {"user_id": "injected"},
])
def test_registration_validation(client, changes):
    payload = {"name": "Назар", "email": "nazar@example.com", "password": "Test-password-123"} | changes
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422
    assert "input" not in response.text
    assert payload["password"] not in response.text


def test_statuses_and_protected_stage_three_routes(client):
    response = client.post("/api/v1/auth/login", content="{bad json", headers={"Content-Type": "application/json"})
    assert response.status_code == 400
    assert client.get("/api/v1/recipes").status_code == 401
    assert client.get("/api/v1/meal-plans").status_code == 401
    assert client.get("/api/v1/shopping-items").status_code == 401
    assert client.get("/docs").status_code == 200
    schema = client.get("/openapi.json").json()
    assert len(schema["paths"]) == 11
    assert client.get("/api/v1/not-a-route").status_code == 404
    assert schema["paths"]["/api/v1/users/me"]["get"]["security"] == [{"HTTPBearer": []}]
