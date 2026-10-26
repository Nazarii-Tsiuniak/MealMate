import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/utils/meal_plan_dates.dart';
import 'package:mealmate/data/api/api_client.dart';
import 'package:mealmate/data/repositories/auth_repository.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/models/recipe_ingredient.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/services/auth_service.dart';
import 'package:mealmate/services/nutrition_service.dart';
import 'package:mealmate/services/server/server_controller.dart';
import 'server_auth_test.dart' show MemoryTokenStore;

const liveUrl = String.fromEnvironment('MEALMATE_LIVE_API');
void main() {
  test(
    'Live FastAPI: auth, CRUD, plan, purchases, statistics and restored session',
    () async {
      final tokens = MemoryTokenStore();
      final api = ApiClient(baseUrl: Uri.parse(liveUrl));
      final auth = AuthService(AuthRepository(api), tokens);
      addTearDown(() {
        auth.dispose();
        api.close();
      });
      final email =
          'flutter.${DateTime.now().microsecondsSinceEpoch}@example.com';
      await auth.register('Назарій', email, 'Test-password-123');
      await auth.login(email, 'Test-password-123');
      expect(tokens.value, isNotNull);
      final server = ServerController(auth);
      addTearDown(server.dispose);
      await server.refresh();
      expect(server.error, isNull);
      expect(server.recipes.recipes, isEmpty);
      const draft = Recipe(
        id: '',
        name: 'Тестовий омлет',
        category: RecipeCategory.breakfast,
        preparationMinutes: 15,
        calories: 320,
        servings: 2,
        ingredients: [
          RecipeIngredient(name: 'Яйця', quantity: 4, unit: 'шт'),
          RecipeIngredient(name: 'Молоко', quantity: 100, unit: 'мл'),
          RecipeIngredient(name: 'Сіль', note: 'за смаком'),
        ],
        preparationSteps: ['Приготувати'],
      );
      final created = await server.recipes.saveAsync(draft);
      expect(server.recipes.recipes.length, 1);
      expect(
        (await server.recipeRepository.fetch(
          search: 'ОМЛЕТ',
          category: RecipeCategory.breakfast,
        )).single.id,
        created.id,
      );
      await server.recipes.loadDetails(created.id);
      final today = MealPlanDates.day(DateTime.now());
      await server.plans.assignAsync(
        today,
        MealType.breakfast,
        created.id,
        plannedServings: 0.5,
      );
      expect(NutritionService(server.plans).forDate(today).knownCalories, 160);
      expect(
        NutritionService(server.plans).forWeek(today).average,
        closeTo(160 / 7, 1e-8),
      );
      expect(
        server.shopping.items
            .singleWhere((v) => v.ingredientName == 'Молоко')
            .quantity,
        25,
      );
      final manual = await server.shopping.addManualAsync(
        week: server.shopping.selectedWeek,
        name: 'Хліб',
        quantity: 1,
        unit: 'шт',
        category: ShoppingCategory.other,
      );
      await server.shopping.setPurchasedAsync(manual.id, true);
      expect(server.shopping.purchased, 1);
      await server.settings.setDailyGoalAsync(150);
      expect(auth.user!.dailyGoal, 150);
      final secondApi = ApiClient(baseUrl: Uri.parse(liveUrl));
      final restored = AuthService(AuthRepository(secondApi), tokens);
      addTearDown(() {
        restored.dispose();
        secondApi.close();
      });
      await restored.restore();
      expect(restored.user!.id, auth.user!.id);
      final second = ServerController(restored);
      addTearDown(second.dispose);
      await second.refresh();
      expect(second.error, isNull);
      expect(second.recipes.recipes.single.id, created.id);
      expect(second.plans.forDate(today).single.plannedServings, 0.5);
      expect(
        second.shopping.items.singleWhere((v) => v.id == manual.id).isPurchased,
        isTrue,
      );
      expect(second.settings.dailyGoal, 150);
      await server.recipes.saveAsync(
        Recipe(
          id: created.id,
          name: 'Оновлений омлет',
          category: created.category,
          preparationMinutes: 15,
          calories: 400,
          servings: 4,
          ingredients: created.ingredients,
          preparationSteps: created.preparationSteps,
        ),
      );
      expect(NutritionService(server.plans).forDate(today).knownCalories, 200);
      expect(
        server.shopping.items
            .singleWhere((v) => v.ingredientName == 'Молоко')
            .quantity,
        12.5,
      );
      await server.plans.setServingsAsync(today, MealType.breakfast, 2);
      expect(NutritionService(server.plans).forDate(today).knownCalories, 800);
      await server.plans.removeAsync(today, MealType.breakfast);
      expect(server.shopping.items.single.id, manual.id);
      await server.recipes.deleteAsync(created.id);
      await server.shopping.removeAsync(manual.id);
      expect(server.recipes.recipes, isEmpty);
      expect(server.shopping.items, isEmpty);
      await auth.logout();
      expect(tokens.value, isNull);
    },
    skip: liveUrl.isEmpty
        ? 'Потрібен MEALMATE_LIVE_API з окремим тестовим FastAPI'
        : false,
  );
}
