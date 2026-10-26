from app.core.errors import DomainError
from app.schemas.meal_plan import MealPlanRead
from app.services.domain_utils import monday


class MealPlanService:
    def __init__(self, repository, recipes, shopping):
        self.repository = repository
        self.recipes = recipes
        self.shopping = shopping

    def list(self, user_id, start, end):
        if end < start:
            raise DomainError(422, "Кінцева дата має бути не раніше початкової")
        return [MealPlanRead.model_validate(slot) for slot in self.repository.between(user_id, start, end)]

    def assign(self, user_id, data):
        with self.repository.transaction():
            if self.recipes.find(user_id, str(data.recipe_id)) is None:
                raise DomainError(404, "Рецепт не знайдено")
            slot = self.repository.assign(user_id, data)
            self.shopping.synchronize(user_id, {monday(data.date)})
            result = MealPlanRead.model_validate(slot)
        return result

    def delete(self, user_id, plan_id):
        with self.repository.transaction():
            slot = self.repository.find(user_id, plan_id)
            if slot is None:
                raise DomainError(404, "Заплановану страву не знайдено")
            week = monday(slot.date)
            self.repository.delete(slot)
            self.shopping.synchronize(user_id, {week})
