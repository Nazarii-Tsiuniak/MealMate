import '../../models/user_profile.dart';
import '../api/api_client.dart';
import '../api/json_fields.dart';

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;
  UserProfile profile(Object? value) {
    final data = JsonFields.object(value);
    final goal = JsonFields.integer(data['daily_calorie_goal']);
    if (goal <= 0 || goal > 100000) {
      throw const FormatException('Некоректна ціль');
    }
    return UserProfile(
      id: JsonFields.uuid(data['id']),
      name: JsonFields.text(data['name']),
      email: JsonFields.text(data['email']),
      dailyGoal: goal,
    );
  }

  Future<void> register(String name, String email, String password) async {
    profile(
      await api.request(
        'POST',
        'auth/register',
        authenticated: false,
        expected: {201},
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      ),
    );
  }

  Future<String> login(String email, String password) async {
    final data = JsonFields.object(
      await api.request(
        'POST',
        'auth/login',
        authenticated: false,
        body: {'email': email.trim(), 'password': password},
      ),
    );
    if (data['token_type'] != 'bearer' ||
        JsonFields.integer(data['expires_in']) <= 0) {
      throw const FormatException('Некоректний токен');
    }
    return JsonFields.text(data['access_token']);
  }

  Future<UserProfile> me() async =>
      profile(await api.request('GET', 'users/me'));
  Future<UserProfile> setGoal(int goal) async => profile(
    await api.request('PATCH', 'users/me', body: {'daily_calorie_goal': goal}),
  );
}
