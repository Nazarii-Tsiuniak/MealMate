import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../services/nutrition_service.dart';

class WeeklyCalorieChart extends StatelessWidget {
  const WeeklyCalorieChart({
    required this.week,
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final WeeklyNutrition week;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  @override
  Widget build(BuildContext context) {
    final maxValue = week.days.fold(
      1.0,
      (value, day) => math.max(value, day.knownCalories),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Калорійність за тиждень',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${week.isComplete ? 'Середнє' : 'Середнє відомих калорій'}: ${NutritionService.number(double.parse(week.average.toStringAsFixed(1)))} ккал / день',
          ),
          const Text(
            'У середньому враховано всі 7 днів',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(constraints.maxWidth, 7 * 52.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in week.days)
                      Expanded(
                        child: Semantics(
                          label:
                              '${MealPlanDates.label(day.date)}: ${day.label}',
                          selected: day.date == MealPlanDates.day(selected),
                          child: InkWell(
                            key: ValueKey('calorie-day-${day.date.weekday}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onSelected(day.date),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 90,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        height: math.max(
                                          4,
                                          90 * day.knownCalories / maxValue,
                                        ),
                                        width: 24,
                                        decoration: BoxDecoration(
                                          color:
                                              day.date ==
                                                  MealPlanDates.day(selected)
                                              ? AppColors.primary
                                              : AppColors.lightGreen,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    MealPlanDates
                                        .shortWeekdays[day.date.weekday - 1],
                                  ),
                                  Text('${day.date.day}'),
                                  if (!day.isComplete)
                                    const Text(
                                      '*',
                                      semanticsLabel: 'Неповні дані',
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            '${MealPlanDates.label(selected)}: ${week.days.singleWhere((day) => day.date == MealPlanDates.day(selected)).label}',
            key: const ValueKey('chart-selected-calories'),
          ),
          if (!week.isComplete)
            const Text(
              '* Є страви без вказаної калорійності. Стовпчики показують лише відомі калорії.',
            ),
          const SizedBox(height: 8),
          const Text(
            'Натисніть на день, щоб переглянути його план.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
