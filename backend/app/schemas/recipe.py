from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer, StringConstraints, model_validator

Category = Literal["breakfast", "lunch", "dinner", "salad", "dessert"]
Unit = Literal["г", "кг", "мл", "л", "шт"]
Title = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Step = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=10000)]
Number = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]
Quantity = Annotated[Number, Field(gt=0, le=1000000000, max_digits=18, decimal_places=6, allow_inf_nan=False)]


class InputModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class IngredientInput(InputModel):
    name: Title
    quantity: Quantity | None = None
    unit: Unit | None = None
    note: Literal["за смаком"] | None = None

    @model_validator(mode="after")
    def amount(self):
        if self.quantity is None:
            if self.unit is not None or self.note != "за смаком":
                raise ValueError("Для невизначеної кількості вкажіть «за смаком» без одиниці")
        elif self.unit is None or self.note is not None:
            raise ValueError("Для числової кількості потрібна одиниця без «за смаком»")
        return self


class RecipeInput(InputModel):
    name: Title
    description: Annotated[str, StringConstraints(strip_whitespace=True, max_length=20000)] = ""
    category: Category
    preparation_minutes: Annotated[int, Field(strict=True, gt=0, le=1000000)]
    calories: Annotated[int, Field(strict=True, ge=0, le=1000000000)] | None = None
    servings: Annotated[int, Field(strict=True, gt=0, le=1000000)]
    ingredients: list[IngredientInput] = Field(min_length=1, max_length=200)
    preparation_steps: list[Step] = Field(min_length=1, max_length=200)


class IngredientRead(BaseModel):
    name: str
    quantity: Number | None
    unit: Unit | None
    note: str | None


class RecipeRead(BaseModel):
    id: UUID
    name: str
    description: str
    category: Category
    preparation_minutes: int
    calories: int | None
    servings: int
    ingredients: list[IngredientRead]
    preparation_steps: list[str]
