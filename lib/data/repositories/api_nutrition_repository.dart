import '../../services/nutrition_service.dart';
import '../api/api_client.dart';
import '../api/backend_json.dart';
import '../api/json_fields.dart';

class ApiNutritionRepository {
  ApiNutritionRepository(this.api);
  final ApiClient api;
  final Map<DateTime, DailyNutrition> days = {};
  final Map<DateTime, WeeklyNutrition> weeks = {};
  Future<DailyNutrition> fetchDay(DateTime date) async {
    final value = BackendJson.day(
      await api.request(
        'GET',
        'statistics/daily',
        query: {'date': JsonFields.dateText(date)},
      ),
    );
    if (value.date != date) {
      throw const FormatException('Статистика іншої дати');
    }
    return value;
  }

  Future<WeeklyNutrition> fetchWeek(DateTime week) async {
    final value = BackendJson.week(
      await api.request(
        'GET',
        'statistics/weekly',
        query: {'start_date': JsonFields.dateText(week)},
      ),
    );
    if (value.days.first.date != week) {
      throw const FormatException('Статистика іншого тижня');
    }
    return value;
  }

  void remember(WeeklyNutrition week) {
    weeks[week.days.first.date] = week;
    for (final day in week.days) {
      days[day.date] = day;
    }
  }
}
