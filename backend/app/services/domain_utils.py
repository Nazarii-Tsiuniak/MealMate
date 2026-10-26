from datetime import timedelta
from decimal import Decimal
import re
from app.core.errors import DomainError


def normalize_name(value):
    return re.sub(r"\s+", " ", value.strip().lower().replace("’", "'"))


def shift(day, count):
    try:
        return day + timedelta(days=count)
    except OverflowError:
        raise DomainError(422, "Дата виходить за підтримуваний діапазон") from None


def monday(day):
    return shift(day, -day.weekday())


def base_unit(unit):
    return {"кг": "г", "л": "мл"}.get(unit, unit)


def base_quantity(quantity, unit):
    return None if quantity is None else Decimal(quantity) * (1000 if unit in ("кг", "л") else 1)


def same_quantity(first, second):
    if first is None or second is None:
        return first is second
    return abs(first - second) <= max(abs(first), abs(second)) * Decimal("1e-10")


def category(name):
    groups = {
        "vegetables": ['картопля','морква','цибуля','зелена цибуля','зелень','помідори','огірки','листя салату','часник','банан','ягоди','полуниця','яблуко'],
        "dairy": ['молоко','вершкове масло','сир','кисломолочний сир','сметана','йогурт','кефір','вершки'],
        "meatFish": ['куряче філе','курка','яловичина','свинина','риба','лосось'],
        "groceries": ['борошно','цукор','вівсяні пластівці','вівсянка','рис','гречка','макарони','оливкова олія','олія','мед'],
        "spices": ['сіль','перець','чорний перець','кориця','ваніль'],
    }
    key = normalize_name(name)
    return next((group for group, names in groups.items() if key in names), "other")
