import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/meal_plan_dates.dart';

class WeekCalendar extends StatelessWidget {
  const WeekCalendar({
    required this.selected,
    required this.onSelected,
    required this.onWeekChanged,
    super.key,
  });
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int> onWeekChanged;
  @override
  Widget build(BuildContext context) {
    final start = MealPlanDates.monday(selected);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Попередній тиждень',
              onPressed: () => onWeekChanged(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                MealPlanDates.weekLabel(start),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            IconButton(
              tooltip: 'Наступний тиждень',
              onPressed: () => onWeekChanged(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth / 7).clamp(54.0, 80.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < 7; index++)
                    Builder(
                      builder: (context) {
                        final date = MealPlanDates.shift(start, index);
                        final active = date == MealPlanDates.day(selected);
                        return SizedBox(
                          width: width,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 8,
                            ),
                            child: Semantics(
                              selected: active,
                              label: MealPlanDates.label(date),
                              child: Material(
                                color: active
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  key: ValueKey('plan-day-$index'),
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => onSelected(date),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          MealPlanDates.shortWeekdays[index],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: active
                                                ? Colors.white
                                                : AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: active
                                                ? Colors.white
                                                : AppColors.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
