import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/action_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../models/meal_plan.dart';
import '../../services/meal_plan_service.dart';
import '../../services/nutrition_service.dart';
import '../../widgets/meal_plan/weekly_calorie_chart.dart';
import '../../widgets/meal_plan/planned_servings_dialog.dart';
import '../../widgets/meal_plan/meal_slot_card.dart';
import '../../widgets/meal_plan/week_calendar.dart';
import 'recipe_picker_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({required this.service, this.initialDate, super.key});
  final MealPlanService service;
  final DateTime? initialDate;
  @override
  State<MealPlanScreen> createState() => MealPlanScreenState();
}

class MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _selected;
  @override
  void initState() {
    super.initState();
    _selected = MealPlanDates.day(widget.initialDate ?? DateTime.now());
  }

  void showDate(DateTime date) {
    setState(() => _selected = MealPlanDates.day(date));
    unawaited(widget.service.loadWeek(date));
  }

  Future<void> _choose(MealType type) async {
    final date = _selected;
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecipePickerScreen(recipes: widget.service.recipes),
      ),
    );
    if (!mounted || id == null) return;
    try {
      await widget.service.assignAsync(
        date,
        type,
        id,
        plannedServings: widget.service.slot(date, type)?.plannedServings ?? 1,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _servings(MealType type) async {
    final date = _selected;
    final slot = widget.service.slot(date, type);
    if (slot == null) return;
    final value = await showDialog<double>(
      context: context,
      builder: (_) => PlannedServingsDialog(initialValue: slot.plannedServings),
    );
    if (!mounted || value == null || widget.service.slot(date, type) == null) {
      return;
    }
    await runAction(
      context,
      () => widget.service.setServingsAsync(date, type, value),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) => ListView(
      key: const PageStorageKey('meal-plan'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text(
          'План харчування',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        WeekCalendar(
          selected: _selected,
          onSelected: showDate,
          onWeekChanged: (direction) =>
              showDate(MealPlanDates.shift(_selected, direction * 7)),
        ),
        const Divider(height: 32, color: Color(0xFFE0E6E1)),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              MealPlanDates.label(_selected),
              key: const ValueKey('selected-plan-date'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              'Заплановано: ${widget.service.forDate(_selected).length} із 3',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          NutritionService(widget.service).forDate(_selected).label,
          key: const ValueKey('selected-day-calories'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        if (!NutritionService(widget.service).forDate(_selected).isComplete)
          const Text(
            'Підсумок неповний: для частини страв калорійність не вказана.',
          ),
        const SizedBox(height: 24),
        for (final type in MealType.values)
          MealSlotCard(
            type: type,
            plannedServings:
                widget.service.slot(_selected, type)?.plannedServings ?? 1,
            calories: NutritionService(
              widget.service,
            ).mealCalories(_selected, type),
            onServings: () => _servings(type),
            recipe: widget.service.recipeFor(_selected, type),
            onChoose: () => _choose(type),
            onRemove: () => runAction(
              context,
              () => widget.service.removeAsync(_selected, type),
            ),
          ),
        WeeklyCalorieChart(
          week: NutritionService(widget.service).forWeek(_selected),
          selected: _selected,
          onSelected: showDate,
        ),
      ],
    ),
  );
}
