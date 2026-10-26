from datetime import date
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator
from app.schemas.recipe import InputModel

MealType = Literal["breakfast", "lunch", "dinner"]


class MealPlanInput(InputModel):
    date: date
    meal_type: MealType
    recipe_id: UUID
    planned_servings: Annotated[float, Field(gt=0, le=1000, allow_inf_nan=False)] = 1

    @field_validator("planned_servings", mode="before")
    @classmethod
    def numeric_portions(cls, value):
        if isinstance(value, bool):
            raise ValueError("Кількість порцій має бути числом")
        return value



class MealPlanRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    date: date
    meal_type: MealType
    recipe_id: UUID
    planned_servings: float
