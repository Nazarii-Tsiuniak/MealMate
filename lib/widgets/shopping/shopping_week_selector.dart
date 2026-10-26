import 'package:flutter/material.dart';
import '../../core/utils/meal_plan_dates.dart';

class ShoppingWeekSelector extends StatelessWidget {
  const ShoppingWeekSelector({
    required this.week,
    required this.onSelected,
    super.key,
  });
  final DateTime week;
  final ValueChanged<DateTime> onSelected;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Попередній тиждень покупок',
            onPressed: () => onSelected(MealPlanDates.shift(week, -7)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              MealPlanDates.weekLabel(week),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Наступний тиждень покупок',
            onPressed: () => onSelected(MealPlanDates.shift(week, 7)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      TextButton.icon(
        onPressed: () => onSelected(DateTime.now()),
        icon: const Icon(Icons.today_outlined, size: 18),
        label: const Text('Поточний тиждень'),
      ),
    ],
  );
}
