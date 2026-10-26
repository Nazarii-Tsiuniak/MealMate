import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/nutrition_service.dart';
import 'package:mealmate/services/nutrition_settings_service.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/meal_plan/meal_plan_screen.dart';
import 'package:mealmate/screens/profile/profile_screen.dart';
import 'package:mealmate/widgets/home/calorie_goal_card.dart';
import 'package:mealmate/widgets/meal_plan/weekly_calorie_chart.dart';
import 'package:mealmate/widgets/meal_plan/planned_servings_dialog.dart';

Finder vertical() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;
Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(vertical()).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 150, scrollable: vertical());
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  late RecipeService recipes;
  late MealPlanService plans;
  late NutritionSettingsService settings;
  final day = DateTime(2026, 12, 28);
  setUp(() {
    recipes = RecipeService.demo();
    plans = MealPlanService.inMemory(recipes);
    settings = NutritionSettingsService();
  });
  tearDown(() {
    settings.dispose();
    plans.dispose();
    recipes.dispose();
  });

  testWidgets('Profile goal validates and Home updates after returning', (
    tester,
  ) async {
    plans.assign(DateTime.now(), MealType.breakfast, 'omelet');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(
          service: recipes,
          mealPlans: plans,
          nutritionSettings: settings,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Профіль'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('daily-calorie-goal'));
    for (final value in ['', '0', '-5', '1.5', 'NaN']) {
      await tester.enterText(input, value);
      await tester.tap(find.text('Зберегти ціль'));
      await tester.pumpAndSettle();
      expect(find.text('Введіть ціле число від 1 до 100000'), findsOneWidget);
      expect(settings.dailyGoal, 2000);
    }
    await tester.enterText(input, '250');
    await tester.tap(find.text('Зберегти ціль'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(CalorieGoalCard));
    expect(find.text('Денна ціль: 250 ккал'), findsOneWidget);
    expect(find.text('Перевищення: 70 ккал'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    await reveal(tester, find.text('Змінити ціль'));
    await tester.tap(find.text('Змінити ціль'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(input).controller!.text, '250');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Portions dialog validates, saves fractional portions and updates day and week',
    (tester) async {
      plans.assign(day, MealType.breakfast, 'omelet');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MealPlanScreen(service: plans, initialDate: day),
          ),
        ),
      );
      await reveal(tester, find.byKey(const ValueKey('servings-breakfast')));
      await tester.tap(find.byKey(const ValueKey('servings-breakfast')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('planned-servings-input'));
      for (final value in ['', '0', '-1', 'NaN', 'Infinity', '1001']) {
        await tester.enterText(field, value);
        await tester.tap(find.text('Зберегти'));
        await tester.pumpAndSettle();
        expect(find.text('Введіть число більше 0 і до 1000'), findsOneWidget);
      }
      await tester.enterText(field, '0,25');
      await tester.tap(find.text('Зберегти'));
      await tester.pumpAndSettle();
      expect(plans.slot(day, MealType.breakfast)!.plannedServings, 0.25);
      await reveal(tester, find.byKey(const ValueKey('selected-day-calories')));
      expect(find.text('80 ккал'), findsOneWidget);
      await reveal(tester, find.byType(WeeklyCalorieChart));
      expect(find.text('Середнє: 11,4 ккал / день'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('calorie-day-2')));
      await tester.tap(find.byKey(const ValueKey('calorie-day-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('chart-selected-calories')))
            .data,
        'Вівторок, 29 грудня: 0 ккал',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Unknown calories mark both daily card and weekly average incomplete',
    (tester) async {
      plans.assign(day, MealType.breakfast, 'oatmeal');
      final nutrition = NutritionService(plans);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                CalorieGoalCard(
                  day: nutrition.forDate(day),
                  goal: 2000,
                  onGoal: () {},
                ),
                WeeklyCalorieChart(
                  week: nutrition.forWeek(day),
                  selected: day,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Щонайменше 0 ккал'), findsOneWidget);
      expect(find.textContaining('Підсумок неповний'), findsOneWidget);
      await reveal(tester, find.byType(WeeklyCalorieChart));
      expect(
        find.text('Середнє відомих калорій: 0 ккал / день'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(280, 480),
    const Size(320, 568),
    const Size(640, 360),
  ]) {
    testWidgets('Nutrition UI supports keyboard and 200% font at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      plans.assign(day, MealType.breakfast, 'omelet', plannedServings: 1000);
      Widget app(Widget body) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: body,
      );
      await tester.pumpWidget(
        app(
          Scaffold(
            body: MealPlanScreen(service: plans, initialDate: day),
          ),
        ),
      );
      await reveal(tester, find.byType(WeeklyCalorieChart));
      await reveal(
        tester,
        find.byKey(const ValueKey('chart-selected-calories')),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: CalorieGoalCard(
                day: NutritionService(plans).forDate(day),
                goal: 2000,
                onGoal: () {},
              ),
            ),
          ),
        ),
      );
      await reveal(tester, find.text('Змінити ціль'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(ProfileScreen(settings: settings)));
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Зберегти ціль'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<double>(
                  context: context,
                  builder: (_) =>
                      const PlannedServingsDialog(initialValue: 0.25),
                ),
                child: const Text('Порції'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Порції'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Скасувати'));
      await tester.tap(find.text('Скасувати'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
