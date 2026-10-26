import secrets
import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_secret_is_required_and_never_echoed(monkeypatch):
    monkeypatch.delenv("MEALMATE_JWT_SECRET", raising=False)
    with pytest.raises(ValidationError): Settings(_env_file=None)
    for secret in ["", "short", "x" * 64]:
        with pytest.raises(ValidationError) as error:
            Settings(_env_file=None, jwt_secret=secret)
        assert "input_value" not in str(error.value)
    settings = Settings(_env_file=None, jwt_secret=secrets.token_hex(32))
    assert settings.jwt_secret.get_secret_value() not in repr(settings)
