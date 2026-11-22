import '../core/utils/meal_plan_dates.dart';

enum MealType {
  breakfast('Сніданок', '08:00'),
  lunch('Обід', '13:00'),
  dinner('Вечеря', '19:00');

  const MealType(this.label, this.time);
  final String label;
  final String time;
}

class MealPlan {
  static void validateServings(double value) {
    if (!value.isFinite || value <= 0 || value > 1000) {
      throw ArgumentError('Вкажіть кількість порцій від 0 до 1000 (більше 0)');
    }
  }

  MealPlan({
    required this.id,
    required DateTime date,
    required this.mealType,
    required this.recipeId,
    this.plannedServings = 1,
  }) : date = MealPlanDates.day(date);
  final String id;
  final DateTime date;
  final MealType mealType;
  final String recipeId;

  final double plannedServings;
}
