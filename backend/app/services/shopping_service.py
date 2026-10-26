from decimal import Decimal, ROUND_HALF_UP
from app.core.errors import DomainError
from app.database.models import ShoppingItem
from app.schemas.shopping import ShoppingInput, ShoppingRead
from app.services.domain_utils import base_quantity, base_unit, category, monday, normalize_name, same_quantity, shift


class ShoppingService:
    def __init__(self, repository, plans):
        self.repository = repository
        self.plans = plans

    def read(self, item):
        quantity, unit = item.quantity, item.unit
        if not item.is_manual and quantity is not None and quantity >= 1000 and unit in ("г", "мл"):
            quantity /= 1000
            unit = "кг" if unit == "г" else "л"
        return ShoppingRead(id=item.id, week_start=item.week_start,
            ingredient_name=item.ingredient_name, quantity=quantity, unit=unit,
            category=item.category, is_manual=item.is_manual, is_purchased=item.is_purchased)

    def list(self, user_id, week):
        return [self.read(item) for item in self.repository.for_week(user_id, monday(week))]

    def synchronize(self, user_id, weeks):
        # Викликається лише всередині транзакції зміни рецепта/плану.
        for week in sorted(set(weeks)):
            amounts = {}
            for slot in self.plans.between(user_id, week, shift(week, 6)):
                recipe = slot.recipe
                factor = Decimal(str(slot.planned_servings)) / recipe.servings
                for entry in recipe.ingredients:
                    name = entry.ingredient.name
                    unit = base_unit(entry.unit) if entry.quantity is not None else None
                    key = normalize_name(name) + "|" + (unit if unit else "taste")
                    if key not in amounts:
                        amounts[key] = [name, None if entry.quantity is None else Decimal(0), unit]
                    if entry.quantity is not None:
                        amounts[key][1] += base_quantity(entry.quantity, entry.unit) * factor
            previous = {item.aggregation_key: item for item in self.repository.for_week(user_id, week) if not item.is_manual}
            for key, (name, quantity, unit) in amounts.items():
                if quantity is not None:
                    # Поточна схема SQLite зберігає 6 знаків у канонічних г/мл/шт.
                    quantity = quantity.quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
                    if quantity <= 0:
                        raise DomainError(422, "Розрахована кількість продукту надто мала для точності сховища")
                item = previous.pop(key, None)
                if item is None:
                    item = ShoppingItem(user_id=user_id, week_start=week, aggregation_key=key,
                        is_manual=False, is_purchased=False)
                elif not same_quantity(base_quantity(item.quantity, item.unit), quantity):
                    item.is_purchased = False
                item.ingredient_name = name
                item.quantity = quantity
                item.unit = unit
                item.category = category(name)
                self.repository.add(item)
            for item in previous.values():
                self.repository.delete(item)
            self.repository.flush()

    def create(self, user_id, data):
        with self.repository.transaction():
            values = data.model_dump()
            values["week_start"] = monday(values["week_start"])
            item = self.repository.add(ShoppingItem(user_id=user_id, is_manual=True, **values))
            result = self.read(item)
        return result

    def patch(self, user_id, item_id, data):
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            raise DomainError(400, "Вкажіть хоча б одне поле для оновлення")
        with self.repository.transaction():
            item = self.repository.find(user_id, item_id)
            if item is None:
                raise DomainError(404, "Продукт не знайдено")
            if not item.is_manual and set(changes) - {"is_purchased"}:
                raise DomainError(409, "Кількість автоматичного продукту змінюється через рецепт або план")
            if item.is_manual:
                values = {"week_start": item.week_start, "ingredient_name": item.ingredient_name,
                    "quantity": item.quantity, "unit": item.unit, "category": item.category}
                values.update({key: value for key, value in changes.items() if key != "is_purchased"})
                # Перевіряємо результат часткового оновлення, а не лише передані поля.
                try:
                    merged = ShoppingInput.model_validate(values)
                except ValueError:
                    raise DomainError(422, "Вкажіть коректні кількість і одиницю разом або обидва null для «за смаком»") from None
                unchanged = normalize_name(item.ingredient_name) == normalize_name(merged.ingredient_name) and base_unit(item.unit) == base_unit(merged.unit) and same_quantity(base_quantity(item.quantity, item.unit), base_quantity(merged.quantity, merged.unit))
                for key in ("ingredient_name", "quantity", "unit", "category"):
                    setattr(item, key, getattr(merged, key))
                item.is_purchased = changes.get("is_purchased", item.is_purchased) if unchanged else False
            else:
                item.is_purchased = changes["is_purchased"]
            self.repository.flush()
            result = self.read(item)
        return result

    def delete(self, user_id, item_id):
        with self.repository.transaction():
            item = self.repository.find(user_id, item_id)
            if item is None:
                raise DomainError(404, "Продукт не знайдено")
            if not item.is_manual:
                raise DomainError(409, "Автоматичний продукт можна прибрати зміною плану або рецепта")
            self.repository.delete(item)
