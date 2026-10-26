from app.core.errors import DomainError
from app.schemas.meal_plan import MealPlanRead


class MealPlanService:
    def __init__(self, repository):
        self.repository = repository

    def list(self, user_id, start, end):
        if end < start:
            raise DomainError(422, "Кінцева дата має бути не раніше початкової")
        return [MealPlanRead.model_validate(slot) for slot in self.repository.between(user_id, start, end)]

    def find(self, user_id, plan_id):
        slot = self.repository.find(user_id, plan_id)
        if slot is None:
            raise DomainError(404, "Заплановану страву не знайдено")
        return slot
