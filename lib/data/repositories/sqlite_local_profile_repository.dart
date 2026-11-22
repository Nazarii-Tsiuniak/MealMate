import 'package:sqflite/sqflite.dart';
import '../../models/local_profile.dart';
import '../local/app_database.dart';
import '../local/local_storage_exception.dart';

class SqliteLocalProfileRepository {
  const SqliteLocalProfileRepository(this.database);
  final AppDatabase database;

  LocalProfile _profile(Map<String, Object?> row) => LocalProfile(
    name: row['name'] as String,
    dailyGoal: row['daily_calorie_goal'] as int,
  );

  Future<LocalProfile> initialize() => database.transaction((txn) async {
    await txn.insert('local_profile', {
      'id': 1,
      'name': 'Назарій',
      'daily_calorie_goal': 2000,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('metadata', {
      'key': 'profile_initialized',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return _profile(
      (await txn.query(
        'local_profile',
        where: 'id = ?',
        whereArgs: [1],
      )).single,
    );
  });

  Future<LocalProfile> update({String? name, int? dailyGoal}) async {
    if (name != null) LocalProfile.validateName(name);
    if (dailyGoal != null) LocalProfile.validateGoal(dailyGoal);
    return database.transaction((txn) async {
      final rows = await txn.query(
        'local_profile',
        where: 'id = ?',
        whereArgs: [1],
      );
      if (rows.length != 1) {
        throw const LocalStorageException(
          'Локальний профіль ще не завантажено. Повторіть запуск.',
        );
      }
      final values = <String, Object?>{
        if (name != null) 'name': name.trim(),
        if (dailyGoal != null) 'daily_calorie_goal': dailyGoal,
      };
      if (values.isNotEmpty) {
        await txn.update(
          'local_profile',
          values,
          where: 'id = ?',
          whereArgs: [1],
        );
      }
      return _profile(
        (await txn.query(
          'local_profile',
          where: 'id = ?',
          whereArgs: [1],
        )).single,
      );
    });
  }
}
