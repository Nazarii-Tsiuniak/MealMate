import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/data/repositories/in_memory_recipe_repository.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/models/recipe_ingredient.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/recipe_validation.dart';

Recipe valid({
  String id = '',
  String name = 'Новий рецепт',
  List<RecipeIngredient>? ingredients,
  List<String>? steps,
}) => Recipe(
  id: id,
  name: name,
  category: RecipeCategory.lunch,
  preparationMinutes: 20,
  servings: 2,
  calories: 0,
  ingredients:
      ingredients ?? const [RecipeIngredient(name: 'Сіль', note: 'за смаком')],
  preparationSteps: steps ?? const ['Змішати'],
);

void main() {
  test('CRUD has unique IDs, immutable snapshots and shared notifications', () {
    final service = RecipeService(InMemoryRecipeRepository());
    addTearDown(service.dispose);
    var notifications = 0;
    service.addListener(() => notifications++);
    final first = service.save(valid());
    final second = service.save(valid(name: 'Другий'));
    expect(first.id, isNot(second.id));
    expect(service.findById(first.id)!.name, 'Новий рецепт');
    service.save(valid(id: first.id, name: 'Оновлено'));
    expect(service.findById(first.id)!.name, 'Оновлено');
    expect(service.recipes.length, 2);
    expect(() => service.recipes.clear(), throwsUnsupportedError);
    expect(
      () => service.findById(first.id)!.ingredients.clear(),
      throwsUnsupportedError,
    );
    expect(service.delete(first.id), isTrue);
    expect(service.findById(first.id), isNull);
    expect(service.delete(first.id), isFalse);
    final third = service.save(valid());
    expect({first.id, second.id, third.id}.length, 3);
    expect(notifications, 5);
    expect(() => service.save(valid(id: first.id)), throwsStateError);
    expect(service.recipes.length, 2);
  });

  test('Business validation rejects incomplete and non-finite ingredients', () {
    final service = RecipeService(InMemoryRecipeRepository());
    addTearDown(service.dispose);
    for (final recipe in [
      valid(name: '   '),
      valid(ingredients: []),
      valid(steps: []),
      valid(steps: ['Добре', ' ']),
      valid(
        ingredients: const [
          RecipeIngredient(name: 'Вода', quantity: 0, unit: 'мл'),
        ],
      ),
      valid(
        ingredients: const [
          RecipeIngredient(name: 'Вода', quantity: double.nan, unit: 'мл'),
        ],
      ),
      valid(ingredients: const [RecipeIngredient(name: 'Вода')]),
      valid(
        ingredients: const [RecipeIngredient(name: ' ', note: 'за смаком')],
      ),
      valid(
        ingredients: const [
          RecipeIngredient(name: 'Вода', quantity: 1, unit: 'неіснуюча'),
        ],
      ),
    ]) {
      expect(() => service.save(recipe), throwsArgumentError);
    }
    expect(service.recipes, isEmpty);
    expect(RecipeValidation.quantity('1,5'), isNull);
    expect(RecipeValidation.quantity('Infinity'), isNotNull);
    expect(RecipeValidation.positiveInteger('1.5'), isNotNull);
    expect(RecipeValidation.calories('-1'), isNotNull);
    expect(RecipeValidation.calories('0'), isNull);
    expect(RecipeValidation.calories(''), isNull);
  });

  test(
    'Fresh launch restores demo data without changes to initial records',
    () {
      final first = RecipeService.demo();
      final second = RecipeService.demo();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first.delete('omelet');
      expect(first.recipes.length, 5);
      expect(second.recipes.length, 6);
      expect(second.findById('omelet'), isNotNull);
    },
  );
}
