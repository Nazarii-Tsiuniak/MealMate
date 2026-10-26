from datetime import date
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, field_validator, model_validator
from app.schemas.recipe import InputModel, Number, Quantity, Title, Unit

ShoppingCategory = Literal["vegetables", "dairy", "meatFish", "groceries", "spices", "other"]


class ShoppingInput(InputModel):
    week_start: date
    ingredient_name: Title
    quantity: Quantity | None = None
    unit: Unit | None = None
    category: ShoppingCategory = "other"

    @model_validator(mode="after")
    def amount(self):
        if (self.quantity is None) != (self.unit is None):
            raise ValueError("Вкажіть кількість і одиницю разом або залиште обидва null для «за смаком»")
        return self


class ShoppingPatch(InputModel):
    ingredient_name: Title | None = None
    quantity: Quantity | None = None
    unit: Unit | None = None
    category: ShoppingCategory | None = None
    is_purchased: bool | None = None

    @field_validator("ingredient_name", "category", "is_purchased")
    @classmethod
    def nonnull(cls, value):
        if value is None:
            raise ValueError("Поле не може бути null")
        return value

    @field_validator("is_purchased", mode="before")
    @classmethod
    def boolean(cls, value):
        if not isinstance(value, bool):
            raise ValueError("Потрібне логічне значення")
        return value


class ShoppingRead(BaseModel):
    id: UUID
    week_start: date
    ingredient_name: str
    quantity: Number | None
    unit: Unit | None
    category: ShoppingCategory
    is_manual: bool
    is_purchased: bool
