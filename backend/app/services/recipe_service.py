from app.core.errors import DomainError
from app.schemas.recipe import IngredientRead, RecipeRead
from app.services.domain_utils import monday, normalize_name


class RecipeService:
    def __init__(self, repository, plans, shopping):
        self.repository = repository
        self.plans = plans
        self.shopping = shopping

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
        # SQLite lower() не виконує Unicode case folding для українських назв.
        if search and search.strip():
            key = normalize_name(search)
            recipes = [recipe for recipe in recipes if key in normalize_name(recipe.name)]
        return [self.read(recipe) for recipe in recipes]

    def details(self, user_id, recipe_id):
        return self.read(self.find(user_id, recipe_id))

    def save(self, user_id, data, recipe_id=None):
        with self.repository.transaction():
            recipe = None if recipe_id is None else self.find(user_id, recipe_id)
            weeks = set() if recipe is None else {monday(day) for day in self.plans.recipe_dates(user_id, recipe_id)}
            recipe = self.repository.save(user_id, data, normalize_name, recipe)
            self.shopping.synchronize(user_id, weeks)
            result = self.read(recipe)
        return result

    def delete(self, user_id, recipe_id):
        with self.repository.transaction():
            self.find(user_id, recipe_id)
            weeks = {monday(day) for day in self.plans.recipe_dates(user_id, recipe_id)}
            self.repository.delete(user_id, recipe_id)
            self.shopping.synchronize(user_id, weeks)
