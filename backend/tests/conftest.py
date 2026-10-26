from pathlib import Path
import secrets

from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
import pytest

from app.core.config import Settings
from app.main import create_app

ROOT = Path(__file__).resolve().parents[1]


def migration_config(url: str) -> Config:
    config = Config(str(ROOT / "alembic.ini"))
    config.attributes["database_url"] = url
    return config


@pytest.fixture
def settings(tmp_path):
    return Settings(_env_file=None, jwt_secret=secrets.token_hex(32),
        database_url="sqlite:///" + str(tmp_path / "test.db"))


@pytest.fixture
def application(settings):
    command.upgrade(migration_config(settings.database_url), "head")
    app = create_app(settings)
    yield app
    app.state.engine.dispose()


@pytest.fixture
def client(application):
    with TestClient(application, raise_server_exceptions=False) as client:
        yield client


def register(client, email="nazar@example.com", password="Test-password-123", name="Назар"):
    return client.post("/api/v1/auth/register", json={"name": name, "email": email, "password": password})


def login(client, email="nazar@example.com", password="Test-password-123"):
    return client.post("/api/v1/auth/login", json={"email": email, "password": password})


def auth(client, email="nazar@example.com"):
    response = login(client, email=email)
    assert response.status_code == 200, response.text
    return {"Authorization": "Bearer " + response.json()["access_token"]}
