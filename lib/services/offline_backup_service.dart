import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../data/local/app_database.dart';
import '../data/local/local_storage_exception.dart';
import '../data/repositories/sqlite_meal_plan_repository.dart';
import '../models/local_profile.dart';
import '../models/recipe.dart';
import '../models/recipe_ingredient.dart';
import '../models/meal_plan.dart';
import '../models/shopping_item.dart';
import 'recipe_validation.dart';

class OfflineBackupService {
  OfflineBackupService(
    this.database, {
    required this.reload,
    this.beforeAccess,
    this.prepareCommit,
  });
  final AppDatabase database;
  final Future<void> Function() reload;
  final Future<void> Function()? beforeAccess;
  final Future<void Function()> Function(Transaction)? prepareCommit;
  static const columns = {
    'recipes': {
      'id',
      'name',
      'description',
      'category',
      'preparation_minutes',
      'calories',
      'servings',
      'sort_order',
    },
    'recipe_ingredients': {
      'recipe_id',
      'position',
      'name',
      'quantity',
      'unit',
      'note',
    },
    'preparation_steps': {'recipe_id', 'position', 'text'},
    'meal_plans': {'id', 'date', 'meal_type', 'recipe_id', 'planned_servings'},
    'shopping_items': {
      'id',
      'week_start',
      'ingredient_name',
      'quantity',
      'unit',
      'category',
      'is_manual',
      'is_purchased',
      'aggregation_key',
    },
  };
  Future<Map<String, dynamic>> _snapshot(Transaction txn) async {
    final profile = (await txn.query('local_profile')).single;
    final metadata = await txn.query(
      'metadata',
      where: 'key IN (?,?)',
      whereArgs: ['recipe_seed_version', 'shopping_state'],
    );
    return {
      'format': 'mealmate-offline',
      'version': 1,
      'mode': 'backup',
      'profile': {
        'name': profile['name'],
        'daily_calorie_goal': profile['daily_calorie_goal'],
      },
      'tables': {
        for (final table in columns.keys) table: await txn.query(table),
      },
      'metadata': {
        for (final row in metadata) row['key'] as String: row['value'],
      },
    };
  }

  Future<String> exportText() async {
    await beforeAccess?.call();
    return jsonEncode(await database.transaction(_snapshot));
  }

  Future<String?> previousText() => database.transaction((txn) async {
    final rows = await txn.query(
      'metadata',
      where: 'key=?',
      whereArgs: ['last_restore_backup'],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  });
  static String _text(Object? v) {
    if (v is! String || v.trim().isEmpty) {
      throw const FormatException('Некоректний текст у копії');
    }
    return v;
  }

  static DateTime _date(Object? v) {
    final text = _text(v);
    final date = DateTime.tryParse(text);
    if (date == null || localDate(date) != text) {
      throw const FormatException('Некоректна дата в копії');
    }
    return date;
  }

  static double? _quantity(Object? v) {
    if (v == null) return null;
    if (v is! num || !v.isFinite || v <= 0) {
      throw const FormatException('Некоректна кількість у копії');
    }
    return v.toDouble();
  }

  Map<String, dynamic> validate(String text) {
    if (utf8.encode(text).length > 10 * 1024 * 1024) {
      throw const FormatException('Копія перевищує 10 МБ');
    }
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (data['format'] != 'mealmate-offline' ||
        data['version'] != 1 ||
        !['backup', 'server'].contains(data['mode']) ||
        data.keys.any(
          (k) => !{
            'format',
            'version',
            'mode',
            'profile',
            'tables',
            'metadata',
          }.contains(k),
        )) {
      throw const FormatException('Непідтримуваний формат резервної копії');
    }
    final profile = data['profile'] as Map<String, dynamic>;
    if (profile.keys.any((k) => !{'name', 'daily_calorie_goal'}.contains(k))) {
      throw const FormatException('Зайві поля профілю');
    }
    LocalProfile.validateName(_text(profile['name']));
    LocalProfile.validateGoal(profile['daily_calorie_goal'] as int);
    final tables = data['tables'] as Map<String, dynamic>;
    if (tables.length != columns.length ||
        tables.keys.any((k) => !columns.containsKey(k))) {
      throw const FormatException('Некоректні таблиці копії');
    }
    for (final table in columns.keys) {
      final rows = tables[table] as List;
      if (rows.length > 50000) {
        throw const FormatException('Завелика кількість записів');
      }
      for (final row in rows.cast<Map<String, dynamic>>()) {
        if (row.keys.toSet().difference(columns[table]!).isNotEmpty ||
            !row.keys.toSet().containsAll(columns[table]!)) {
          throw const FormatException('Некоректні поля таблиці');
        }
      }
    }
    List<Map<String, dynamic>> rows(String key) =>
        (tables[key] as List).cast<Map<String, dynamic>>();
    final recipes = rows('recipes');
    final ids = <String>{};
    final orders = <int>{};
    for (final r in recipes) {
      final id = _text(r['id']);
      if (!ids.add(id) ||
          r['sort_order'] is! int ||
          !orders.add(r['sort_order'] as int)) {
        throw const FormatException('Повторні ID або порядок рецептів');
      }
      final ingredients =
          rows('recipe_ingredients').where((i) => i['recipe_id'] == id).toList()
            ..sort(
              (a, b) => (a['position'] as int).compareTo(b['position'] as int),
            );
      final steps =
          rows('preparation_steps').where((i) => i['recipe_id'] == id).toList()
            ..sort(
              (a, b) => (a['position'] as int).compareTo(b['position'] as int),
            );
      RecipeValidation.prepare(
        Recipe(
          id: id,
          name: _text(r['name']),
          description: r['description'] as String,
          category: RecipeCategory.values.byName(r['category'] as String),
          preparationMinutes: r['preparation_minutes'] as int,
          calories: r['calories'] as int?,
          servings: r['servings'] as int,
          ingredients: ingredients
              .map(
                (i) => RecipeIngredient(
                  name: _text(i['name']),
                  quantity: _quantity(i['quantity']),
                  unit: i['unit'] as String?,
                  note: i['note'] as String?,
                ),
              )
              .toList(),
          preparationSteps: steps.map((i) => _text(i['text'])).toList(),
        ),
      );
    }
    for (final table in ['recipe_ingredients', 'preparation_steps']) {
      final positions = <String>{};
      for (final row in rows(table)) {
        if (!ids.contains(row['recipe_id']) ||
            row['position'] is! int ||
            (row['position'] as int) <= 0 ||
            !positions.add('${row['recipe_id']}|${row['position']}')) {
          throw const FormatException(
            'Пошкоджені зв’язки інгредієнтів або кроків',
          );
        }
      }
    }
    final planIds = <String>{};
    final slots = <String>{};
    for (final row in rows('meal_plans')) {
      if (!planIds.add(_text(row['id'])) || !ids.contains(row['recipe_id'])) {
        throw const FormatException('Пошкоджені зв’язки плану');
      }
      _date(row['date']);
      MealType.values.byName(row['meal_type'] as String);
      if (!slots.add('${row['date']}|${row['meal_type']}')) {
        throw const FormatException('Повторні прийоми їжі');
      }
      MealPlan.validateServings(_quantity(row['planned_servings'])!);
    }
    final shopIds = <String>{};
    final keys = <String>{};
    for (final row in rows('shopping_items')) {
      final date = _date(row['week_start']);
      if (date.weekday != 1 || !shopIds.add(_text(row['id']))) {
        throw const FormatException('Некоректні покупки');
      }
      _text(row['ingredient_name']);
      ShoppingCategory.values.byName(row['category'] as String);
      final amount = _quantity(row['quantity']);
      if ((amount == null) != (row['unit'] == null) ||
          (amount != null && !RecipeIngredient.units.contains(row['unit'])) ||
          ![0, 1].contains(row['is_manual']) ||
          ![0, 1].contains(row['is_purchased']) ||
          (row['is_manual'] == 1
              ? row['aggregation_key'] != null
              : row['aggregation_key'] is! String) ||
          (row['is_manual'] == 0 &&
              !keys.add('${row['week_start']}|${row['aggregation_key']}'))) {
        throw const FormatException('Некоректні кількості або ознаки покупок');
      }
    }
    final meta = data['metadata'] as Map<String, dynamic>;
    if (meta.keys.any(
          (k) => !{'recipe_seed_version', 'shopping_state'}.contains(k),
        ) ||
        meta['recipe_seed_version'] != '2') {
      throw const FormatException('Невідома версія початкових даних');
    }
    if (meta['shopping_state'] != null) {
      final state =
          jsonDecode(meta['shopping_state'] as String) as Map<String, dynamic>;
      if (state['sequence'] is! int || (state['sequence'] as int) < 0) {
        throw const FormatException('Некоректний стан покупок');
      }
      for (final e in (state['sources'] as Map<String, dynamic>).entries) {
        _date(e.key);
        _text(e.value);
      }
      for (final e in (state['removed'] as Map<String, dynamic>).entries) {
        _date(e.key);
        for (final key in e.value as List) {
          _text(key);
        }
      }
    }
    return data;
  }

  Future<void> importText(String text, {bool? replace}) async {
    final Map<String, dynamic> data;
    try {
      data = validate(text);
    } catch (_) {
      throw const LocalStorageException(
        'Файл пошкоджений або має непідтримуваний формат. Дані не змінено.',
      );
    }
    await beforeAccess?.call();
    final replacing = replace ?? data['mode'] == 'backup';
    final publish = await database.transaction((txn) async {
      final previous = jsonEncode(await _snapshot(txn));
      final tables = data['tables'] as Map<String, dynamic>;
      if (replacing) {
        await txn.delete('shopping_items');
        await txn.delete('meal_plans');
        await txn.delete('recipes');
      }
      for (final raw in tables['recipes'] as List) {
        final row = Map<String, Object?>.from(raw as Map);
        final existing = await txn.query(
          'recipes',
          columns: ['id'],
          where: 'id=?',
          whereArgs: [row['id']],
        );
        if (existing.isEmpty) {
          if (!replacing) {
            row['sort_order'] = (await txn.rawQuery(
              'SELECT COALESCE(MAX(sort_order),0)+1 AS value FROM recipes',
            )).single['value'];
          }
          await txn.insert('recipes', row);
        } else {
          final updates = Map<String, Object?>.from(row)
            ..remove('id')
            ..remove('sort_order');
          await txn.update(
            'recipes',
            updates,
            where: 'id=?',
            whereArgs: [row['id']],
          );
          await txn.delete(
            'recipe_ingredients',
            where: 'recipe_id=?',
            whereArgs: [row['id']],
          );
          await txn.delete(
            'preparation_steps',
            where: 'recipe_id=?',
            whereArgs: [row['id']],
          );
        }
      }
      for (final table in [
        'recipe_ingredients',
        'preparation_steps',
        'meal_plans',
      ]) {
        for (final row in tables[table] as List) {
          await txn.insert(
            table,
            Map<String, Object?>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      for (final raw in tables['shopping_items'] as List) {
        final row = Map<String, Object?>.from(raw as Map);
        if (!replacing && row['is_manual'] == 0) {
          final matching = await txn.query(
            'shopping_items',
            where: 'week_start=? AND aggregation_key=?',
            whereArgs: [row['week_start'], row['aggregation_key']],
          );
          if (matching.isNotEmpty) row['id'] = matching.single['id'];
        }
        await txn.insert(
          'shopping_items',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final profile = Map<String, Object?>.from(data['profile'] as Map)
        ..['id'] = 1;
      await txn.insert(
        'local_profile',
        profile,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final metadata = data['metadata'] as Map<String, dynamic>;
      if (replacing) {
        await txn.delete(
          'metadata',
          where: 'key=?',
          whereArgs: ['shopping_state'],
        );
      }
      for (final e in metadata.entries) {
        await txn.insert('metadata', {
          'key': e.key,
          'value': e.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('metadata', {
        'key': 'last_restore_backup',
        'value': previous,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if ((await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const LocalStorageException(
          'Порушено зв’язки даних. Імпорт скасовано.',
        );
      }
      return await prepareCommit?.call(txn);
    });
    publish?.call();
    await reload();
  }
}
