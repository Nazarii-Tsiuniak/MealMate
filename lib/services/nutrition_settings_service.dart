import 'package:flutter/foundation.dart';

/// Особиста ціль у пам’яті поточного запуску. 2000 — демонстраційний приклад.
class NutritionSettingsService extends ChangeNotifier {
  bool get isRemote => false;
  Future<void> setDailyGoalAsync(int value) async => setDailyGoal(value);
  int _dailyGoal = 2000;
  int get dailyGoal => _dailyGoal;
  void setDailyGoal(int value) {
    if (value <= 0 || value > 100000) {
      throw ArgumentError('Введіть ціле число від 1 до 100000');
    }
    if (_dailyGoal == value) return;
    _dailyGoal = value;
    notifyListeners();
  }
}
