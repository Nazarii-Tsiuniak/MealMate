from app.core.errors import DomainError
from app.schemas.recipe import IngredientRead, RecipeRead
from app.services.domain_utils import normalize_name


class RecipeService:
    def __init__(self, repository):
        self.repository = repository

    def find(self, user_id, recipe_id):
        recipe = self.repository.find(user_id, recipe_id)
        if recipe is None:
            raise DomainError(404, "Рецепт не знайдено")
        return recipe

    def read(self, recipe):
        return RecipeRead(id=recipe.id, name=recipe.name, description=recipe.description,
            category=recipe.category, preparation_minutes=recipe.preparation_minutes,
            calories=recipe.calories, servings=recipe.servings,
            ingredients=[IngredientRead(name=row.ingredient.name, quantity=row.quantity,
                unit=row.unit, note=row.note) for row in recipe.ingredients],
            preparation_steps=[row.text for row in recipe.steps])

    def list(self, user_id, search=None, category=None):
        recipes = self.repository.all(user_id, category)

        if search and search.strip():
            key = normalize_name(search)
            recipes = [recipe for recipe in recipes if key in normalize_name(recipe.name)]
        return [self.read(recipe) for recipe in recipes]

    def details(self, user_id, recipe_id):
        return self.read(self.find(user_id, recipe_id))
