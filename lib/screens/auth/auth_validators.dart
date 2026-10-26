/// Перевірки введення для форм; не виконують авторизацію.
abstract final class AuthValidators {
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введіть ім’я';
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Введіть електронну пошту';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Введіть коректну електронну пошту';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введіть пароль';
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Створіть пароль';
    if (value.length < 8) return 'Пароль має містити щонайменше 8 символів';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.trim().isEmpty) return 'Підтвердьте пароль';
    if (value != password) return 'Паролі не збігаються';
    return null;
  }
}
