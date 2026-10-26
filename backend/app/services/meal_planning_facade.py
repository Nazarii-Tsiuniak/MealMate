from app.schemas.meal_plan import MealPlanInput, MealPlanRead
from app.schemas.recipe import RecipeInput, RecipeRead
from app.services.domain_utils import monday, normalize_name
from app.services.meal_plan_service import MealPlanService
from app.services.recipe_service import RecipeService
from app.services.shopping_service import ShoppingService


class MealPlanningFacade:
    def __init__(self, recipes: RecipeService, plans: MealPlanService, shopping: ShoppingService):
        self.recipes = recipes
        self.plans = plans
        self.shopping = shopping

    def _recipe_weeks(self, user_id, recipe_id):
        return {monday(day) for day in self.plans.repository.recipe_dates(user_id, recipe_id)}

    def save_recipe(self, user_id: str, data: RecipeInput, recipe_id: str | None = None) -> RecipeRead:
        with self.recipes.repository.transaction():
            recipe = None if recipe_id is None else self.recipes.find(user_id, recipe_id)
            weeks = set() if recipe is None else self._recipe_weeks(user_id, recipe_id)
            recipe = self.recipes.repository.save(user_id, data, normalize_name, recipe)
            self.shopping.synchronize(user_id, weeks)
            result = self.recipes.read(recipe)
        return result

    def delete_recipe(self, user_id: str, recipe_id: str) -> None:
        with self.recipes.repository.transaction():
            self.recipes.find(user_id, recipe_id)
            weeks = self._recipe_weeks(user_id, recipe_id)
            self.recipes.repository.delete(user_id, recipe_id)
            self.shopping.synchronize(user_id, weeks)

    def assign_meal(self, user_id: str, data: MealPlanInput) -> MealPlanRead:
        with self.plans.repository.transaction():
            self.recipes.find(user_id, str(data.recipe_id))
            slot = self.plans.repository.assign(user_id, data)
            self.shopping.synchronize(user_id, {monday(data.date)})
            result = MealPlanRead.model_validate(slot)
        return result

    def delete_meal(self, user_id: str, plan_id: str) -> None:
        with self.plans.repository.transaction():
            slot = self.plans.find(user_id, plan_id)
            week = monday(slot.date)
            self.plans.repository.delete(slot)
            self.shopping.synchronize(user_id, {week})
