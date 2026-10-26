/// Імена маршрутів застосунку. Рецепти відкриваються з явною передачею
/// спільного RecipeService; окремі сховища в маршрутах не створюються.
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const recipes = '/recipes';
  static const mealPlan = '/meal-plan';
  static const shoppingList = '/shopping-list';
  static const profile = '/profile';
  static const recipeDetails = '/recipes/details';
  static const addEditRecipe = '/recipes/edit';
}
