import '../data/repositories/sqlite_local_profile_repository.dart';
import '../models/local_profile.dart';
import 'nutrition_settings_service.dart';

class LocalProfileService extends NutritionSettingsService {
  LocalProfileService._(this._repository, this._profile);
  final SqliteLocalProfileRepository _repository;
  LocalProfile _profile;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  static Future<LocalProfileService> load(
    SqliteLocalProfileRepository repository,
  ) async => LocalProfileService._(repository, await repository.initialize());

  String get name => _profile.name;
  @override
  int get dailyGoal => _profile.dailyGoal;
  Future<void> get flushed => _pending;
  Future<void> reload() async {
    await _pending;
    _profile = await _repository.initialize();
    if (!_disposed) notifyListeners();
  }

  Future<void> _update({String? name, int? dailyGoal}) {
    if (_disposed) return Future.error(StateError('Профіль закрито'));
    final operation = _pending.then((_) async {
      final saved = await _repository.update(name: name, dailyGoal: dailyGoal);
      _profile = saved;
      if (!_disposed) notifyListeners();
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> save({required String name, required int dailyGoal}) =>
      _update(name: name, dailyGoal: dailyGoal);
  Future<void> setNameAsync(String name) => _update(name: name);
  @override
  Future<void> setDailyGoalAsync(int value) => _update(dailyGoal: value);
  @override
  void setDailyGoal(int value) =>
      throw UnsupportedError('Використайте setDailyGoalAsync');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
