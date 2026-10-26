from pydantic import BaseModel, ConfigDict, EmailStr, Field, SecretStr, field_validator

from app.schemas.user import Name, normalize_email


class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Name
    email: EmailStr
    password: SecretStr = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def normalized_email(cls, value):
        return normalize_email(value)

    @field_validator("password")
    @classmethod
    def valid_password(cls, value: SecretStr):
        if not value.get_secret_value().strip():
            raise ValueError("Пароль не може складатися лише з пробілів")
        return value


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: EmailStr
    password: SecretStr = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def normalized_email(cls, value):
        return normalize_email(value)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
