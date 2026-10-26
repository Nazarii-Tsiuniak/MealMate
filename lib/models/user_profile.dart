class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.dailyGoal,
  });
  final String id, name, email;
  final int dailyGoal;
}
