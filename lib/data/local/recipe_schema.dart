import 'package:sqflite/sqflite.dart';

abstract final class RecipeSchema {
  static Future<void> create(Database db) async {
    await db.execute("""
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY NOT NULL CHECK (length(trim(id)) > 0),
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        description TEXT NOT NULL,
        category TEXT NOT NULL CHECK (category IN ('breakfast','lunch','dinner','salad','dessert')),
        preparation_minutes INTEGER NOT NULL CHECK (preparation_minutes > 0),
        calories INTEGER CHECK (calories IS NULL OR (typeof(calories) = 'integer' AND calories >= 0)),
        servings INTEGER NOT NULL CHECK (typeof(servings) = 'integer' AND servings > 0),
        sort_order INTEGER NOT NULL UNIQUE
      )
    """);
    await db.execute("""
      CREATE TABLE recipe_ingredients (
        recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        position INTEGER NOT NULL CHECK (position > 0),
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        quantity REAL,
        unit TEXT,
        note TEXT,
        PRIMARY KEY (recipe_id, position),
        CHECK ((quantity IS NULL AND unit IS NULL AND note = 'за смаком' AND note IS NOT NULL)
          OR (quantity IS NOT NULL AND quantity > 0 AND unit IS NOT NULL AND unit IN ('г','кг','мл','л','шт')))
      )
    """);
    await db.execute("""
      CREATE TABLE preparation_steps (
        recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        position INTEGER NOT NULL CHECK (position > 0),
        text TEXT NOT NULL CHECK (length(trim(text)) > 0),
        PRIMARY KEY (recipe_id, position)
      )
    """);
  }
}
