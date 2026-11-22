import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';
import 'local_storage_exception.dart';
import 'recipe_schema.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _path = databasePath;

  static const fileName = 'mealmate_offline.db';
  static const schemaVersion = 4;
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _opening;
  Future<void>? _closing;

  Future<Database> open() async {
    final closing = _closing;
    if (closing != null) await closing;
    return _opening ??= _open().onError((Object error, StackTrace stack) {
      _opening = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<Database> _open() async {
    try {
      final path =
          _path ?? paths.join(await _factory.getDatabasesPath(), fileName);
      return await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => _migrate(db, 0, version),
          onUpgrade: _migrate,
          onDowngrade: (db, oldVersion, newVersion) async {
            throw const LocalStorageException(
              'Базу створено новішою версією MealMate. Оновіть застосунок.',
            );
          },
        ),
      );
    } on LocalStorageException {
      rethrow;
    } catch (_) {
      throw const LocalStorageException(
        'Не вдалося відкрити локальну базу. Дані не видалено. Спробуйте ще раз.',
      );
    }
  }

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 1:
          await db.execute("""
            CREATE TABLE local_profile (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
              daily_calorie_goal INTEGER NOT NULL
                CHECK (typeof(daily_calorie_goal) = 'integer' AND daily_calorie_goal BETWEEN 1 AND 100000)
            )
          """);
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
          );
        case 2:
          await RecipeSchema.create(db);
        case 3:
          await db.execute("""
            CREATE TABLE meal_plans (
              id TEXT PRIMARY KEY NOT NULL,
              date TEXT NOT NULL,
              meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast','lunch','dinner')),
              recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
              planned_servings REAL NOT NULL CHECK (planned_servings > 0 AND planned_servings <= 1000),
              UNIQUE(date, meal_type)
            )
          """);
        case 4:
          await db.execute("""
            CREATE TABLE shopping_items (
              id TEXT PRIMARY KEY NOT NULL,
              week_start TEXT NOT NULL,
              ingredient_name TEXT NOT NULL CHECK(length(trim(ingredient_name)) > 0),
              quantity REAL, unit TEXT,
              category TEXT NOT NULL CHECK(category IN ('vegetables','dairy','meatFish','groceries','spices','other')),
              is_manual INTEGER NOT NULL CHECK(is_manual IN (0,1)),
              is_purchased INTEGER NOT NULL CHECK(is_purchased IN (0,1)),
              aggregation_key TEXT,
              UNIQUE(week_start,aggregation_key),
              CHECK((quantity IS NULL AND unit IS NULL) OR (quantity IS NOT NULL AND unit IS NOT NULL AND quantity > 0 AND unit IN ('г','кг','мл','л','шт')))
            )
          """);
        default:
          throw const LocalStorageException(
            'Невідома версія локальної бази. Дані не змінено.',
          );
      }
    }
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      final db = await open();
      return await db.transaction(action);
    } on LocalStorageException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (_) {
      throw const LocalStorageException(
        'Не вдалося зберегти локальні дані. Зміни скасовано. Спробуйте ще раз.',
      );
    }
  }

  Future<void> close() =>
      _closing ??= _close().whenComplete(() => _closing = null);

  Future<void> _close() async {
    final pending = _opening;
    if (pending == null) return;
    try {
      final db = await pending;
      await db.close();
    } finally {
      if (identical(_opening, pending)) _opening = null;
    }
  }
}
