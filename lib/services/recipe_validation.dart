import '../models/recipe.dart';
import '../models/recipe_ingredient.dart';

abstract final class RecipeValidation {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Заповніть це поле' : null;

  static int? integer(String? value) => int.tryParse(value?.trim() ?? '');

  static double? decimal(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  static String? positiveInteger(String? value) {
    final parsed = integer(value);
    return parsed == null || parsed <= 0 ? 'Введіть додатне ціле число' : null;
  }

  static String? calories(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = integer(value);
    return parsed == null || parsed < 0 ? 'Введіть ціле число від 0' : null;
  }

  static String? quantity(String? value) {
    final parsed = decimal(value);
    return parsed == null || !parsed.isFinite || parsed <= 0
        ? 'Введіть додатну кількість'
        : null;
  }

  static String? recipe(Recipe recipe) {
    if (recipe.name.trim().isEmpty) return 'Вкажіть назву рецепта';
    if (recipe.preparationMinutes <= 0) return 'Перевірте час приготування';
    if (recipe.calories != null && recipe.calories! < 0) {
      return 'Калорійність не може бути від’ємною';
    }
    if (recipe.servings == null || recipe.servings! <= 0) {
      return 'Вкажіть кількість порцій';
    }
    if (recipe.ingredients.isEmpty) return 'Додайте хоча б один інгредієнт';
    for (final ingredient in recipe.ingredients) {
      if (ingredient.name.trim().isEmpty) return 'Вкажіть назви інгредієнтів';
      if (ingredient.quantity == null) {
        if (ingredient.note != 'за смаком' || ingredient.unit != null) {
          return 'Оберіть кількість або режим «за смаком»';
        }
      } else if (!ingredient.quantity!.isFinite ||
          ingredient.quantity! <= 0 ||
          !RecipeIngredient.units.contains(ingredient.unit)) {
        return 'Перевірте кількість та одиниці інгредієнтів';
      }
    }
    if (recipe.preparationSteps.isEmpty ||
        recipe.preparationSteps.any((step) => step.trim().isEmpty)) {
      return 'Заповніть усі кроки приготування';
    }
    return null;
  }
}
