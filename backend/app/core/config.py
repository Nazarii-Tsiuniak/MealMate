from pathlib import Path

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="MEALMATE_", env_file=BACKEND_ROOT / ".env",
        env_file_encoding="utf-8", extra="forbid", hide_input_in_errors=True,
    )
    jwt_secret: SecretStr
    database_url: str = "sqlite:///./data/mealmate.db"
    access_token_minutes: int = Field(default=30, ge=1, le=1440)
    jwt_issuer: str = "mealmate-api"
    jwt_audience: str = "mealmate-android"

    @field_validator("jwt_secret")
    @classmethod
    def validate_secret(cls, value: SecretStr) -> SecretStr:
        secret = value.get_secret_value()
        if len(secret.encode("utf-8")) < 32 or not secret.strip():
            raise ValueError("JWT-секрет має містити щонайменше 32 байти")
        if len(set(secret)) < 8:
            raise ValueError("Використайте випадково згенерований JWT-секрет")
        return value

    @field_validator("database_url")
    @classmethod
    def validate_database(cls, value: str) -> str:
        if not value.startswith("sqlite:///"):
            raise ValueError("На цьому етапі підтримується SQLite URL")
        return value
