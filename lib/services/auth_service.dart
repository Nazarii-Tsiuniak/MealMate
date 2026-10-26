import 'package:flutter/foundation.dart';
import '../data/api/api_client.dart';
import '../data/repositories/auth_repository.dart';
import '../models/user_profile.dart';
import '../repositories/token_store.dart';

class AuthService extends ChangeNotifier {
  AuthService(this.repository, this.tokens) {
    repository.api.onUnauthorized = expire;
  }
  final AuthRepository repository;
  final TokenStore tokens;
  UserProfile? user;
  bool restoring = false;
  String? error;
  String? notice;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    restoring = true;
    error = null;
    _notify();
    try {
      repository.api.token = await tokens.read();
      if (repository.api.token != null) user = await repository.me();
    } catch (e) {
      if (e is! ApiException || e.status != 401) {
        error = 'Не вдалося відновити сесію: $e';
      }
    } finally {
      restoring = false;
      _notify();
    }
  }

  Future<void> login(String email, String password) async {
    error = null;
    final token = await repository.login(email, password);
    await tokens.write(token);
    repository.api.token = token;
    user = await repository.me();
    notice = null;
    _notify();
  }

  Future<void> register(String name, String email, String password) =>
      repository.register(name, email, password);
  void acceptProfile(UserProfile value) {
    if (user?.id != value.id) {
      throw const FormatException('Профіль іншого користувача');
    }
    user = value;
    _notify();
  }

  Future<void> setGoal(int goal) async {
    user = await repository.setGoal(goal);
    _notify();
  }

  Future<void> logout() async {
    await tokens.delete();
    repository.api.token = null;
    user = null;
    error = null;
    notice = null;
    _notify();
  }

  Future<void> expire() async {
    repository.api.token = null;
    user = null;
    notice = 'Сесію завершено. Увійдіть повторно.';
    try {
      await tokens.delete();
    } catch (_) {
      error = 'Не вдалося очистити захищене сховище';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    repository.api.onUnauthorized = null;
    super.dispose();
  }
}
