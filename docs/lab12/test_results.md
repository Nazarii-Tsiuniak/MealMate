# Фактичні результати тестування ЛР №12

Дата: 2026-10-26. Контрольна версія: `1145e1f`; гілка роботи: `lab12-design-patterns`.

| Перевірка | До | Після | Доказ |
|---|---|---|---|
| Увесь backend | 138 PASS, 0 FAIL, 0 SKIP | **154 PASS, 0 FAIL, 0 SKIP** | [До](logs/before/backend_all.txt), [після](logs/after/backend_all.txt) |
| Нові Facade-тести | Відсутні | **16 PASS** | [JUnit окремого запуску](logs/facade.xml), [повний прогін](logs/after/backend_all.xml) |
| Unit ЛР11 | 10 PASS | 10 PASS | logs/before/unit.txt, logs/after/unit.txt |
| Integration ЛР11 | 3 PASS | 3 PASS | logs/before/integration.txt, logs/after/integration.txt |
| Functional ЛР11 | 10 PASS | 10 PASS | logs/before/functional.txt, logs/after/functional.txt |
| Flutter test | 125 PASS, 0 FAIL, 1 SKIP | **125 PASS, 0 FAIL, 1 SKIP** | [До JSON](logs/before/flutter_test.jsonl), [після JSON](logs/after/flutter_test.jsonl) |
| Flutter analyze | No issues found | **No issues found** | [До](logs/before/flutter_analyze.txt), [після](logs/after/flutter_analyze.txt) |

Після рефакторингу: **279 унікальних автоматизованих PASS, 0 FAIL, 1 SKIP**. Нові 16 та окремо запущені 23 тести ЛР11 входять до 154 backend-тестів і повторно не додаються до підсумку. Hidden-події завантаження файлів Flutter не рахуються як тести.

Один штатний SKIP — `test/server_live_test.dart`: не задано MEALMATE_LIVE_API з окремим тестовим сервером. Ручне проходження Android-емулятора у цьому етапі **NOT RUN**, його не позначено PASS. Наявні widget-тести не замінюють таку перевірку.

## Нові тести

Файл `backend/tests/test_meal_planning_facade.py`:

- 5 unit-перевірок: порядок begin → перевірка власника → запис → sync → commit; унікальні тижні; відсутність читання дат плану при створенні; передавання 0.5 порції; тиждень видаленого слота.
- 5 параметризованих інтеграційних перевірок відкату: create/update/delete recipe, assign/delete meal. Ін’єкція помилки ShoppingService має HTTP 500 без витоку подробиць; фактичні Recipe/MealPlan/ShoppingItem в SQLite збігаються зі станом до запиту.
- 4 перевірки чужих записів: update/delete recipe, assign/delete meal → 404, синхронізація не викликається, БД незмінна.
- 1 перевірка некоректного input: нульові порції → 422 до відкриття транзакції.
- 1 сценарій оновлення рецепта на двох тижнях: правильні кількості, скидання purchased при зміні кількості, збереження ручної покупки, актуальні денні й тижневі калорії.

Наявні тести не змінено. Нові тести використовують окремі мігровані SQLite через fixtures; unit-заглушки замінюють лише I/O. Дефектів під час виконаних прогонів не виявлено.

## Порівняння контрактів і SQL

В окремих тимчасових SQLite виконано однаковий синтетичний сценарій для коду з `1145e1f` і поточної робочої копії. Для baseline використано тимчасову копію app із початковими версіями п’яти змінених модулів із Git; робочі файли не відкатувалися. Повні OpenAPI, результати статистики/покупок (без випадкових id) та HTTP-статуси збігаються.

Кількість SQL-викликів, включно з авторизацією і транзакційними командами, у цьому сценарії однакова до/після:

| Операція | До | Після |
|---|---:|---:|
| Створення рецепта | 10 | 10 |
| Додавання страви | 11 | 11 |
| Оновлення рецепта | 16 | 16 |
| Денна статистика | 5 | 5 |
| Читання покупок | 2 | 2 |
| Видалення страви | 7 | 7 |
| Видалення рецепта | 5 | 5 |

Це вимірювання конкретного синтетичного сценарію, а не універсальний норматив кількості SQL для будь-якого рецепта. Докази: [порівняння](logs/contract_comparison.json), [baseline](logs/before_contract.json), [після](logs/after_contract.json). Журнали міграцій ізольованих баз: logs/before_contract.txt та logs/after_contract.txt.

## Команди

Усі команди PowerShell від кореня:

```powershell
Set-Location 'D:\IPZ-43\App'
.\backend\.venv\Scripts\python.exe .\backend\scripts\run_lab11.py
```

Цей runner уже виконує backend, flutter analyze та flutter test; повторювати Flutter окремо не потрібно. Його журнали записуються у виключену з Git `docs/lab11/logs/`. Для ЛР12 збережено незмінні копії початкового й фінального прогонів у logs/before та logs/after. Точні команди з cwd, часом UTC, тривалістю та exit_code: [до](logs/before/results.json), [після](logs/after/results.json); лічильники: [до](logs/before/counts.json), [після](logs/after/counts.json).

Окремий запуск нових тестів:

```powershell
.\backend\.venv\Scripts\python.exe -m pytest -c backend/pytest.ini backend/tests/test_meal_planning_facade.py -v
```

Для перевірок створюються тільки тимчасові БД. SHA-256 робочої `backend/data/mealmate.db` не змінився протягом обох прогонів:

`e653ee68499e3a76fb781becce7520af317ef52b66e10a429b78f671d664d6be`

Схема БД/міграції, демонстраційні рецепти, користувачі та їхні дані не змінювалися.
