import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/nutrition_service.dart';
import '../../services/nutrition_settings_service.dart';
import '../../widgets/home/calorie_goal_card.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../models/meal_plan.dart';
import '../../services/meal_plan_service.dart';
import '../../services/shopping_list_service.dart';
import '../../widgets/home/shopping_summary_card.dart';
import '../../widgets/home/meal_card.dart';
import '../../widgets/home/weekly_plan_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.service,
    required this.shopping,
    required this.onPlan,
    required this.onShopping,
    required this.onProfile,
    this.date,
    this.userName,
    this.nutritionSettings,
    super.key,
  });

  final MealPlanService service;
  final ShoppingListService shopping;
  final VoidCallback onPlan;
  final VoidCallback onShopping;
  final VoidCallback onProfile;
  final DateTime? date;
  final String? userName;
  final NutritionSettingsService? nutritionSettings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([service, shopping, nutritionSettings]),
    builder: (context, _) => _buildHome(context),
  );

  Widget _buildHome(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName == null
                        ? 'Добрий ранок, Назарію'
                        : 'Добрий ранок, $userName',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    MealPlanDates.label(date ?? DateTime.now()),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Профіль',
              onPressed: onProfile,
              icon: CircleAvatar(
                backgroundColor: AppColors.lightGreen,
                foregroundColor: AppColors.primary,
                child: Text(
                  userName?.isNotEmpty == true
                      ? userName!.characters.first
                      : 'Н',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        WeeklyPlanCard(
          planned: service.plannedInWeek(date ?? DateTime.now()),
          total: MealPlanService.weeklyTotal,
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            const Text(
              'Сьогодні',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: onPlan,
              child: const Text('Переглянути план'),
            ),
          ],
        ),
        const Text(
          '3 прийоми їжі',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < MealType.values.length; index++) ...[
          MealCard(
            label: MealType.values[index].label,
            name: service
                .recipeFor(date ?? DateTime.now(), MealType.values[index])
                ?.name,
            details: _details(MealType.values[index]),
            icon: [
              Icons.egg_outlined,
              Icons.soup_kitchen_outlined,
              Icons.auto_awesome_outlined,
            ][index],
            iconBackground: [
              const Color(0xFFFFEDBD),
              AppColors.lightGreen,
              const Color(0xFFF4DEDA),
            ][index],
            iconColor: [
              const Color(0xFFA77629),
              AppColors.primary,
              const Color(0xFFB46655),
            ][index],
            onTap: onPlan,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        CalorieGoalCard(
          day: NutritionService(service).forDate(date ?? DateTime.now()),
          goal: nutritionSettings?.dailyGoal ?? 2000,
          onGoal: onProfile,
        ),
        const SizedBox(height: 16),
        ShoppingSummaryCard(shopping: shopping, onShopping: onShopping),
        const SizedBox(height: 12),
        Text(
          service.isRemote
              ? 'План і покупки зберігаються на сервері'
              : 'План зберігається в пам’яті до перезапуску застосунку',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  String _details(MealType type) {
    final recipe = service.recipeFor(date ?? DateTime.now(), type);
    final calories = NutritionService(
      service,
    ).mealCalories(date ?? DateTime.now(), type);
    if (recipe == null) return '0 ккал';
    return [
      '${recipe.preparationMinutes} хв',
      '${NutritionService.number(service.slot(date ?? DateTime.now(), type)!.plannedServings)} порц.',
      calories == null
          ? 'Калорійність не вказана'
          : '${NutritionService.number(calories)} ккал',
    ].join(' · ');
  }
}
