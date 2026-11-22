class LocalProfile {
  const LocalProfile({required this.name, required this.dailyGoal});
  final String name;
  final int dailyGoal;

  static void validateName(String name) {
    if (name.trim().isEmpty || name.trim().runes.length > 80) {
      throw ArgumentError('Введіть ім’я від 1 до 80 символів');
    }
  }

  static void validateGoal(int goal) {
    if (goal < 1 || goal > 100000) {
      throw ArgumentError('Введіть ціле число від 1 до 100000');
    }
  }
}
