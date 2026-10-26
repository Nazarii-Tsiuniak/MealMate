from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload
from app.database.models import Ingredient, PreparationStep, Recipe, RecipeIngredient
from app.repositories.base import Repository


class RecipeRepository(Repository):
    def all(self, user_id: str, category: str | None = None):
        query = select(Recipe).where(Recipe.user_id == user_id).order_by(Recipe.name, Recipe.id)
        if category:
            query = query.where(Recipe.category == category)
        return list(self.session.scalars(query.options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient),
            selectinload(Recipe.steps))))

    def find(self, user_id: str, recipe_id: str):
        return self.session.scalar(select(Recipe).where(Recipe.user_id == user_id, Recipe.id == recipe_id))

    def save(self, user_id, data, normalized_name, recipe=None):
        values = data.model_dump(exclude={"ingredients", "preparation_steps"})
        if recipe is None:
            recipe = Recipe(user_id=user_id, **values)
            self.session.add(recipe)
            self.session.flush()
        else:
            for field, value in values.items():
                setattr(recipe, field, value)
            self.session.execute(delete(RecipeIngredient).where(RecipeIngredient.user_id == user_id, RecipeIngredient.recipe_id == recipe.id))
            self.session.execute(delete(PreparationStep).where(PreparationStep.user_id == user_id, PreparationStep.recipe_id == recipe.id))
            self.session.flush()
        for position, item in enumerate(data.ingredients, 1):
            key = normalized_name(item.name)
            ingredient = self.session.scalar(select(Ingredient).where(Ingredient.user_id == user_id, Ingredient.normalized_name == key))
            if ingredient is None:
                ingredient = Ingredient(user_id=user_id, name=item.name, normalized_name=key)
                self.session.add(ingredient)
                self.session.flush()
            self.session.add(RecipeIngredient(user_id=user_id, recipe_id=recipe.id,
                ingredient_id=ingredient.id, quantity=item.quantity, unit=item.unit,
                note=item.note, position=position))
        for position, text in enumerate(data.preparation_steps, 1):
            self.session.add(PreparationStep(user_id=user_id, recipe_id=recipe.id, position=position, text=text))
        self.session.flush()
        self.session.expire(recipe, ["ingredients", "steps"])
        return recipe

    def delete(self, user_id, recipe_id):
        self.session.execute(delete(Recipe).where(Recipe.user_id == user_id, Recipe.id == recipe_id))
        self.session.flush()
