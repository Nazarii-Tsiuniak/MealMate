import argparse
import json
import sqlite3
from contextlib import closing
from pathlib import Path
from uuid import NAMESPACE_URL, UUID, uuid5

SEED_KEYS = (
    "cheese-tomato-omelet", "banana-oatmeal", "syrnyky", "chicken-vegetable-soup",
    "ukrainian-borscht", "buckwheat-chicken", "creamy-chicken-pasta", "chicken-caesar",
    "baked-potato-meat", "rice-vegetables-turkey",
)


def export_data(database, *, email=None, user_id=None):
    source = Path(database).resolve()
    if not source.is_file():
        raise ValueError("Server database does not exist")
    with closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True, timeout=10)) as db:
        db.row_factory = sqlite3.Row
        db.execute("BEGIN")
        user = db.execute("SELECT id,name,daily_calorie_goal FROM users WHERE " +
                          ("id=?" if user_id else "email=?"), (user_id or email,)).fetchone()
        if user is None:
            raise ValueError("User not found")
        uid = user["id"]
        mapping = {str(uuid5(NAMESPACE_URL, f"mealmate/demo-recipes/v1/{UUID(uid)}/{key}")): "seed-v2-" + key for key in SEED_KEYS}
        def rows(table, columns):
            return [dict(r) for r in db.execute(f"SELECT {columns} FROM {table} WHERE user_id=?", (uid,))]
        recipes = rows("recipes", "id,name,description,category,preparation_minutes,calories,servings")
        for index, row in enumerate(recipes):
            row["id"] = mapping.get(row["id"], row["id"])
            row["sort_order"] = len(recipes) - index
        ingredients = rows("recipe_ingredients", "recipe_id,position,quantity,unit,note,ingredient_id")
        names = {r["id"]: r["name"] for r in db.execute("SELECT id,name FROM ingredients WHERE user_id=?", (uid,))}
        for row in ingredients:
            row["name"] = names[row.pop("ingredient_id")]
            row["recipe_id"] = mapping.get(row["recipe_id"], row["recipe_id"])
        steps = rows("preparation_steps", "recipe_id,position,text")
        plans = rows("meal_plans", "id,date,meal_type,recipe_id,planned_servings")
        for row in steps + plans:
            row["recipe_id"] = mapping.get(row["recipe_id"], row["recipe_id"])
        shopping = rows("shopping_items", "id,week_start,ingredient_name,quantity,unit,category,is_manual,is_purchased,aggregation_key")
        result = {"format": "mealmate-offline", "version": 1, "mode": "server",
                  "profile": {"name": user["name"], "daily_calorie_goal": user["daily_calorie_goal"]},
                  "tables": {"recipes": recipes, "recipe_ingredients": ingredients, "preparation_steps": steps,
                             "meal_plans": plans, "shopping_items": shopping},
                  "metadata": {"recipe_seed_version": "2"}}
        return result


def main():
    parser = argparse.ArgumentParser(description="Read-only export of one MealMate account; no passwords or JWT")
    parser.add_argument("--database", required=True)
    who = parser.add_mutually_exclusive_group(required=True)
    who.add_argument("--user-email")
    who.add_argument("--user-id")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    target = Path(args.output).resolve()
    if target == Path(args.database).resolve():
        parser.error("Output must not overwrite the database")
    if target.exists():
        parser.error("Output already exists; choose another filename")
    data = export_data(args.database, email=args.user_email, user_id=args.user_id)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("x", encoding="utf-8") as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2, allow_nan=False)
    print(f"Exported {len(data['tables']['recipes'])} recipes. Copy the JSON to Android and import it in Profile.")


if __name__ == "__main__":
    main()
