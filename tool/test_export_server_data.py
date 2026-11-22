import hashlib
import json
from pathlib import Path
import secrets
import sys

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "tool"))
from app.core.config import Settings
from app.main import create_app
from scripts.demo_recipes import RECIPES
from scripts.seed_recipes import seed_recipes
from export_server_data import export_data, SEED_KEYS


def test_read_only_export_contains_original_ten_and_no_credentials(tmp_path):
    path = tmp_path / "server.db"
    settings = Settings(_env_file=None, jwt_secret=secrets.token_hex(32), database_url="sqlite:///" + str(path))
    config = Config(str(ROOT / "backend/alembic.ini"))
    config.attributes["database_url"] = settings.database_url
    command.upgrade(config, "head")
    application = create_app(settings)
    with TestClient(application) as client:
        assert client.post("/api/v1/auth/register", json={"name": "Тест", "email": "export@example.com", "password": "Test-password-123"}).status_code == 201
        assert client.post("/api/v1/auth/register", json={"name": "Інший", "email": "other@example.com", "password": "Test-password-123"}).status_code == 201
        with application.state.session_factory() as session:
            assert seed_recipes(session, "export@example.com").created == 10
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        result = export_data(path, email="export@example.com")
        assert hashlib.sha256(path.read_bytes()).hexdigest() == before
        assert set(SEED_KEYS) == {entry.key for entry in RECIPES}
        assert len(result["tables"]["recipes"]) == 10
        assert {r["id"] for r in result["tables"]["recipes"]} == {"seed-v2-" + key for key in SEED_KEYS}
        encoded = json.dumps(result)
        assert all(s not in encoded for s in ["password", "hash", "access_token", "jwt_secret", "other@example.com"])
        assert result["profile"]["name"] == "Тест"
        assert export_data(path, email="other@example.com")["tables"]["recipes"] == []
    application.state.engine.dispose()


def test_missing_database_is_never_created(tmp_path):
    path = tmp_path / "missing.db"
    with pytest.raises(ValueError):
        export_data(path, email="none@example.com")
    assert not path.exists()
