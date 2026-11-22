import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mealmate/data/local/app_database.dart';
import 'package:mealmate/data/local/local_storage_exception.dart';
import 'package:mealmate/data/repositories/sqlite_local_profile_repository.dart';
import 'package:mealmate/services/local_profile_service.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late SqliteLocalProfileRepository repository;
  LocalProfileService? profile;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mealmate-profile-test-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: paths.join(directory.path, AppDatabase.fileName),
    );
    repository = SqliteLocalProfileRepository(database);
    profile = null;
  });
  tearDown(() async {
    await profile?.flushed;
    profile?.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'Current SQLite schema contains profile and recipe tables with foreign keys enabled',
    () async {
      final db = await database.open();
      expect(await db.getVersion(), AppDatabase.schemaVersion);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      final names = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )).map((row) => row['name']).toSet();
      expect(names, {
        'local_profile',
        'metadata',
        'recipes',
        'recipe_ingredients',
        'preparation_steps',
        'meal_plans',
        'shopping_items',
      });
      expect(
        await File(paths.join(directory.path, AppDatabase.fileName)).exists(),
        isTrue,
      );
    },
  );

  test('First launch creates one default local profile', () async {
    profile = await LocalProfileService.load(repository);
    expect(profile!.name, 'Назарій');
    expect(profile!.dailyGoal, 2000);
    final db = await database.open();
    expect((await db.query('local_profile')).length, 1);
    expect((await db.query('metadata')).single['value'], '1');
  });

  test(
    'Initialization is idempotent and never resets an existing profile',
    () async {
      await repository.initialize();
      await repository.update(name: 'Олена', dailyGoal: 1800);
      await Future.wait(List.generate(5, (_) => repository.initialize()));
      final saved = await repository.initialize();
      expect(saved.name, 'Олена');
      expect(saved.dailyGoal, 1800);
      expect((await (await database.open()).query('local_profile')).length, 1);
      expect((await (await database.open()).query('metadata')).length, 1);
    },
  );

  test('Name changes are committed and trimmed', () async {
    profile = await LocalProfileService.load(repository);
    var notifications = 0;
    profile!.addListener(() => notifications++);
    await profile!.setNameAsync('  Марія  ');
    expect(profile!.name, 'Марія');
    expect((await repository.initialize()).name, 'Марія');
    expect(notifications, 1);
  });

  test('Calorie goal is committed before UI notification', () async {
    profile = await LocalProfileService.load(repository);
    var notifications = 0;
    profile!.addListener(() => notifications++);
    await profile!.setDailyGoalAsync(2400);
    expect(profile!.dailyGoal, 2400);
    expect((await repository.initialize()).dailyGoal, 2400);
    expect(notifications, 1);
    expect(() => profile!.setDailyGoal(2100), throwsUnsupportedError);
  });

  test(
    'Profile and goal survive closing and opening a new database instance',
    () async {
      profile = await LocalProfileService.load(repository);
      await profile!.save(name: 'Тарас', dailyGoal: 2250);
      profile!.dispose();
      profile = null;
      await database.close();
      database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: paths.join(directory.path, AppDatabase.fileName),
      );
      repository = SqliteLocalProfileRepository(database);
      profile = await LocalProfileService.load(repository);
      expect(profile!.name, 'Тарас');
      expect(profile!.dailyGoal, 2250);
    },
  );

  test(
    'Invalid goals and names are rejected without changing stored values',
    () async {
      profile = await LocalProfileService.load(repository);
      for (final value in [0, -1, 100001]) {
        await expectLater(
          profile!.setDailyGoalAsync(value),
          throwsArgumentError,
        );
      }
      for (final value in ['', '   ', List.filled(81, 'а').join()]) {
        await expectLater(profile!.setNameAsync(value), throwsArgumentError);
      }
      await expectLater(
        profile!.save(name: 'Не зберігати', dailyGoal: 0),
        throwsArgumentError,
      );
      expect(profile!.name, 'Назарій');
      expect(profile!.dailyGoal, 2000);
      final saved = await repository.initialize();
      expect(saved.name, 'Назарій');
      expect(saved.dailyGoal, 2000);
      await profile!.setDailyGoalAsync(1);
      await profile!.setDailyGoalAsync(100000);
      expect(profile!.dailyGoal, 100000);
    },
  );

  test(
    'Concurrent name and goal updates do not overwrite each other',
    () async {
      profile = await LocalProfileService.load(repository);
      await Future.wait([
        profile!.setNameAsync('Ірина'),
        profile!.setDailyGoalAsync(1950),
      ]);
      final saved = await repository.initialize();
      expect(saved.name, 'Ірина');
      expect(saved.dailyGoal, 1950);
    },
  );

  test(
    'A failed related transaction rolls back both profile and metadata',
    () async {
      await repository.initialize();
      await expectLater(
        database.transaction((txn) async {
          await txn.update('local_profile', {
            'name': 'Не зберігати',
          }, where: 'id = 1');
          await txn.insert('metadata', {'key': 'incomplete', 'value': '1'});
          throw StateError('injected failure');
        }),
        throwsA(isA<LocalStorageException>()),
      );
      expect((await repository.initialize()).name, 'Назарій');
      expect(
        await (await database.open()).query(
          'metadata',
          where: 'key = ?',
          whereArgs: ['incomplete'],
        ),
        isEmpty,
      );
    },
  );

  test(
    'SQLite constraints reject a second profile and an invalid calorie goal',
    () async {
      await repository.initialize();
      final db = await database.open();
      await expectLater(
        db.insert('local_profile', {
          'id': 2,
          'name': 'Другий',
          'daily_calorie_goal': 2000,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.update('local_profile', {'daily_calorie_goal': 0}, where: 'id = 1'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.initialize()).dailyGoal, 2000);
      expect((await db.query('local_profile')).length, 1);
    },
  );

  test(
    'Concurrent opening shares one connection; repeated close and reopen are safe',
    () async {
      final connections = await Future.wait([database.open(), database.open()]);
      expect(identical(connections[0], connections[1]), isTrue);
      await repository.initialize();
      await Future.wait([database.close(), database.close()]);
      expect((await repository.initialize()).name, 'Назарій');
    },
  );

  test(
    'A future database version is rejected without deleting its data',
    () async {
      final dbPath = paths.join(directory.path, AppDatabase.fileName);
      final futureDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion + 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE future_data (value TEXT)');
            await db.insert('future_data', {'value': 'keep'});
          },
        ),
      );
      await futureDb.close();
      await expectLater(database.open(), throwsA(isA<LocalStorageException>()));
      final unchanged = await databaseFactoryFfi.openDatabase(dbPath);
      expect(await unchanged.getVersion(), AppDatabase.schemaVersion + 1);
      expect((await unchanged.query('future_data')).single['value'], 'keep');
      await unchanged.close();
    },
  );
}
