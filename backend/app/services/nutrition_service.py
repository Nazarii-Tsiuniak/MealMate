from decimal import Decimal
from app.schemas.statistics import ChartDay, DailyStatistics, WeeklyStatistics
from app.services.domain_utils import monday, shift


class NutritionService:
    def __init__(self, plans):
        self.plans = plans

    def _daily(self, user, date, slots):
        meals = {"breakfast": Decimal(0), "lunch": Decimal(0), "dinner": Decimal(0)}
        for slot in slots:
            calories = slot.recipe.calories
            meals[slot.meal_type] = None if calories is None else Decimal(calories) * Decimal(str(slot.planned_servings))
        known = sum((value for value in meals.values() if value is not None), Decimal(0))
        complete = all(value is not None for value in meals.values())
        ratio = known / user.daily_calorie_goal
        return DailyStatistics(date=date, meals=meals, known_calories=known,
            total_calories=known if complete else None, daily_goal=user.daily_calorie_goal,
            goal_progress_percent=round(ratio * 100, 2), progress_fraction=min(ratio, 1),
            remaining_calories=Decimal(user.daily_calorie_goal) - known, is_complete=complete)

    def daily(self, user, date):
        return self._daily(user, date, self.plans.between(user.id, date, date))

    def weekly(self, user, start):
        start = monday(start)
        end = shift(start, 6)
        slots = self.plans.between(user.id, start, end)
        days = [self._daily(user, shift(start, index), [slot for slot in slots if slot.date == shift(start, index)]) for index in range(7)]
        return WeeklyStatistics(start_date=start, end_date=end, days=days,
            chart=[ChartDay(date=day.date, calories=day.known_calories, is_complete=day.is_complete) for day in days],
            average_calories=sum(day.known_calories for day in days) / 7,
            is_complete=all(day.is_complete for day in days))
