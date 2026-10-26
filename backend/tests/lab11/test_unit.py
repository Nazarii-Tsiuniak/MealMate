from datetime import date
from decimal import Decimal
from types import SimpleNamespace as NS
from uuid import uuid4

import pytest
from pydantic import ValidationError
from app.schemas.meal_plan import MealPlanInput
from app.schemas.recipe import RecipeInput
from app.services.nutrition_service import NutritionService
from app.services.shopping_service import ShoppingService
from tests.lab11.conftest import recipe_payload, record

DAY = date(2026, 12, 28)
USER = NS(id="unit-user", daily_calorie_goal=2000)


class PlansStub:
    def __init__(self, slots):
        self.slots = slots

    def between(self, user_id, start, end):
        return [slot for slot in self.slots if slot.user_id == user_id and start <= slot.date <= end]


class ShoppingIOStub:
    def __init__(self):
        self.rows = []

    def for_week(self, user_id, week):
        return [row for row in self.rows if row.user_id == user_id and row.week_start == week]

    def add(self, item):
        if item.id is None:
            item.id = str(uuid4())
        if item not in self.rows:
            self.rows.append(item)
        return item

    def delete(self, item):
        self.rows.remove(item)

    def flush(self):
        pass


def slot(portions=1, calories=320, meal="breakfast", day=DAY):
    return NS(user_id=USER.id, date=day, meal_type=meal, planned_servings=portions,
              recipe=NS(calories=calories, servings=2))


def test_UT_001_one_portion(record_property):
    result = NutritionService(PlansStub([slot()])).daily(USER, DAY)
    record(record_property, "UT-001", f"1 порція: {result.total_calories} ккал")
    assert result.total_calories == 320
    assert result.meals == {"breakfast": 320, "lunch": 0, "dinner": 0}


def test_UT_002_half_portion(record_property):
    result = NutritionService(PlansStub([slot(0.5)])).daily(USER, DAY)
    record(record_property, "UT-002", f"0.5 порції: {result.total_calories} ккал")
    assert result.total_calories == 160 and result.is_complete


def test_UT_003_multiple_portions(record_property):
    result = NutritionService(PlansStub([slot(2.5)])).daily(USER, DAY)
    record(record_property, "UT-003", f"2.5 порції: {result.total_calories} ккал")
    assert result.total_calories == 800


def test_UT_004_scale_ingredients(record_property):
    plan = slot(0.5)
    plan.recipe.ingredients = [
        NS(ingredient=NS(name="Молоко"), quantity=Decimal(100), unit="мл"),
        NS(ingredient=NS(name="Яйця"), quantity=Decimal(4), unit="шт"),
        NS(ingredient=NS(name="Сіль"), quantity=None, unit=None),
    ]
    io = ShoppingIOStub()
    ShoppingService(io, PlansStub([plan])).synchronize(USER.id, {DAY})
    rows = {row.ingredient_name: row for row in io.rows}
    record(record_property, "UT-004", f"Молоко {rows['Молоко'].quantity} мл; яйця {rows['Яйця'].quantity} шт; сіль {rows['Сіль'].quantity}")
    assert rows["Молоко"].quantity == Decimal(25)
    assert rows["Яйця"].quantity == Decimal(1)
    assert rows["Сіль"].quantity is None


def test_UT_005_daily_remainder_and_excess(record_property):
    normal = NutritionService(PlansStub([slot()])).daily(USER, DAY)
    over = NutritionService(PlansStub([slot(7)])).daily(USER, DAY)
    record(record_property, "UT-005", f"Залишок {normal.remaining_calories}; після перевищення {over.remaining_calories}")
    assert normal.remaining_calories == 1680
    assert over.remaining_calories == -240 and over.goal_progress_percent == 112
    assert over.progress_fraction == 1


def test_UT_006_invalid_portions(record_property):
    data = {"date": DAY, "meal_type": "breakfast", "recipe_id": str(uuid4())}
    values = [0, -0.5, 1001, float("nan"), float("inf"), True]
    for value in values:
        with pytest.raises(ValidationError):
            MealPlanInput.model_validate(data | {"planned_servings": value})
    record(record_property, "UT-006", f"ValidationError для всіх {len(values)} некоректних значень")


def test_UT_007_required_recipe_fields(record_property):
    for field in ("name", "category", "preparation_minutes", "servings", "ingredients", "preparation_steps"):
        data = recipe_payload()
        del data[field]
        with pytest.raises(ValidationError):
            RecipeInput.model_validate(data)
    for changes in ({"name": " "}, {"ingredients": []}, {"preparation_steps": [" "]}):
        with pytest.raises(ValidationError):
            RecipeInput.model_validate(recipe_payload(**changes))
    record(record_property, "UT-007", "Відсутні обов’язкові поля та порожні рядки/списки відхилено")


def test_UT_008_negative_calories(record_property):
    with pytest.raises(ValidationError):
        RecipeInput.model_validate(recipe_payload(calories=-1))
    assert RecipeInput.model_validate(recipe_payload(calories=0)).calories == 0
    assert RecipeInput.model_validate(recipe_payload(calories=None)).calories is None
    record(record_property, "UT-008", "-1 відхилено; 0 і None збережено як різні значення")


def test_UT_009_daily_aggregation(record_property):
    result = NutritionService(PlansStub([
        slot(1, 320), slot(2, 400, "lunch"), slot(0.5, 220, "dinner"),
        slot(9, 999, day=date(2027, 1, 1)),
    ])).daily(USER, DAY)
    record(record_property, "UT-009", f"Ккал за прийоми: {result.meals}; разом {result.total_calories}")
    assert result.meals == {"breakfast": 320, "lunch": 800, "dinner": 110}
    assert result.total_calories == result.known_calories == 1230


def test_UT_010_weekly_statistics(record_property):
    plans = PlansStub([slot(), slot(1, 200, "lunch"), slot(1.5, 320, "dinner", date(2027, 1, 3)), slot(1, 900, day=date(2027, 1, 4))])
    service = NutritionService(plans)
    result = service.weekly(USER, date(2027, 1, 1))
    assert len(result.days) == len(result.chart) == 7
    assert result.start_date == DAY and result.end_date == date(2027, 1, 3)
    assert result.average_calories == pytest.approx(1000 / 7)
    assert result.days[1].total_calories == 0 and result.is_complete
    plans.slots.append(slot(1, None, "lunch", date(2026, 12, 30)))
    incomplete = service.weekly(USER, DAY)
    assert not incomplete.is_complete and incomplete.days[2].total_calories is None
    assert incomplete.average_calories == pytest.approx(1000 / 7)
    record(record_property, "UT-010", f"Днів {len(result.days)}; середнє {result.average_calories}; невідомі ккал позначено неповними")
