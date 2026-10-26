import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/nutrition_service.dart';

class CalorieGoalCard extends StatelessWidget {
  const CalorieGoalCard({
    required this.day,
    required this.goal,
    required this.onGoal,
    super.key,
  });
  final DailyNutrition day;
  final int goal;
  final VoidCallback onGoal;
  @override
  Widget build(BuildContext context) {
    final target = day.serverGoal ?? goal;
    final difference = day.serverRemaining ?? target - day.knownCalories;
    final text = difference < 0
        ? '${day.isComplete ? 'Перевищення' : 'Відоме перевищення'}: ${NutritionService.number(-difference)} ккал'
        : !day.isComplete
        ? 'Різниця з відомими калоріями: ${NutritionService.number(difference)} ккал'
        : difference == 0
        ? 'Заплановано рівно вашу ціль'
        : 'До цілі: ${NutritionService.number(difference)} ккал';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Калорії на сьогодні',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            day.label,
            key: const ValueKey('today-calories'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text('Денна ціль: $target ккал'),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: (day.serverProgressFraction ?? (day.knownCalories / target))
                .clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Colors.white,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(text),
          if (!day.isComplete)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Підсумок неповний: для частини страв калорійність не вказана.',
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onGoal,
              child: const Text('Змінити ціль'),
            ),
          ),
        ],
      ),
    );
  }
}
