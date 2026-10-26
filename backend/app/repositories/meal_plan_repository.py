from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload
from app.database.models import MealPlan, Recipe, RecipeIngredient
from app.repositories.base import Repository


class MealPlanRepository(Repository):
    def between(self, user_id, start, end):
        return list(self.session.scalars(select(MealPlan).where(
            MealPlan.user_id == user_id, MealPlan.date >= start, MealPlan.date <= end
        ).order_by(MealPlan.date, MealPlan.meal_type).options(
            selectinload(MealPlan.recipe).selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient))))

    def find(self, user_id, plan_id):
        return self.session.scalar(select(MealPlan).where(MealPlan.user_id == user_id, MealPlan.id == plan_id))

    def recipe_dates(self, user_id, recipe_id):
        return list(self.session.scalars(select(MealPlan.date).where(MealPlan.user_id == user_id, MealPlan.recipe_id == recipe_id)))

    def assign(self, user_id, data):
        slot = self.session.scalar(select(MealPlan).where(MealPlan.user_id == user_id,
            MealPlan.date == data.date, MealPlan.meal_type == data.meal_type))
        if slot is None:
            slot = MealPlan(user_id=user_id, date=data.date, meal_type=data.meal_type)
            self.session.add(slot)
        slot.recipe_id = str(data.recipe_id)
        slot.planned_servings = data.planned_servings
        self.session.flush()
        return slot

    def delete(self, slot):
        self.session.delete(slot)
        self.session.flush()
