from typing import Annotated

from pydantic import BaseModel, ConfigDict, EmailStr, Field, StringConstraints, field_validator

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
CalorieGoal = Annotated[int, Field(strict=True, ge=1, le=100000)]


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    email: EmailStr
    name: str
    daily_calorie_goal: int


class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Name | None = None
    email: EmailStr | None = None
    daily_calorie_goal: CalorieGoal | None = None

    @field_validator("name", "email", "daily_calorie_goal")
    @classmethod
    def reject_null(cls, value):
        if value is None:
            raise ValueError("Значення не може бути null")
        return value

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value):
        return normalize_email(value)


def normalize_email(value: str) -> str:
    normalized = str(value).casefold()
    if len(normalized) > 254:
        raise ValueError("Email задовгий")
    return normalized
