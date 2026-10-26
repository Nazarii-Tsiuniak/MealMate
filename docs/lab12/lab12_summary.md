# Лабораторна №12 — підсумок і матеріали захисту

## Результат

В існуючому MealMate впроваджено **один новий патерн Facade**, клас `MealPlanningFacade`. Він зосереджує координацію зміни рецептів/плану та автоматичних покупок у наявній транзакції. RecipeService і MealPlanService тепер залежать кожен лише від свого репозиторію. Повтор визначення тижнів рецепта прибрано. Статистику, HTTP-контракти, авторизацію та алгоритми не змінено.

Strategy не додавався: немає двох необхідних взаємозамінних алгоритмів; денна й тижнева статистики є пов’язаними рівнями одного обчислення. Другий патерн не потрібний для досягнення мети. Наявні Repository, Observer, DI та Flutter ServerController збережені.

Переваги: явна точка координації, менше залежностей предметних сервісів, тести атомарних сценаріїв. Недоліки: додатковий клас і непрямий виклик у write-маршрутах; фасад потрібно обмежувати поточними сценаріями, щоб він не став універсальним сервісом.

## Файли

Створено:

- `backend/app/services/meal_planning_facade.py` — фасад.
- `backend/tests/test_meal_planning_facade.py` — 16 тестів.
- `docs/lab12/architecture_before.md`, `patterns_justification.md`, `architecture_after.md`, `comparison.md`, `test_results.md`, `lab12_summary.md`.
- `docs/lab12/before.mmd`, `after_facade.mmd`, `facade_sequence.mmd` — Mermaid-діаграми; ті самі діаграми вбудовано у Markdown для перегляду. Для Word відрендерити Mermaid і вставити отримане SVG/PNG; сам Word не виконує Mermaid-код.
- `docs/lab12/logs/` — реальні журнали, JUnit, JSON reporter та порівняння контрактів.

Змінено п’ять наявних модулів: `backend/app/dependencies.py`, `backend/app/routers/recipes.py`, `backend/app/routers/meal_plans.py`, `backend/app/services/recipe_service.py`, `backend/app/services/meal_plan_service.py`.

Flutter, SQLAlchemy-моделі, Alembic, репозиторії, seed та формули не змінювалися. Нових залежностей немає.

## Тести та Git

До: backend 138 PASS; Flutter 125 PASS, 1 SKIP; analyze без зауважень.

Після: **backend 154 PASS; Flutter 125 PASS, 1 SKIP; analyze без зауважень**. Нові 16 тестів пройшли як окремо, так і в повному наборі. OpenAPI, HTTP-результати і SQL-лічильники синтетичного сценарію до/після збігаються. Деталі: [test_results.md](test_results.md).

Гілка: **lab12-design-patterns**, створена з чистого `main` на `1145e1f`. На завершення залишені незакомічені зміни п’яти модулів та нові фасад, тести, docs/lab12. Commit і push у цьому етапі не виконувались. Робоча БД не змінена. Word-звіт не створювався.

## Точний перелік скріншотів

| № | Матеріал | Що відкрити |
|---|---|---|
| 1 | Структура до | Термінал: `git ls-tree -r --name-only 1145e1f backend/app lib/services`; початковий код: `git show 1145e1f:backend/app/services/recipe_service.py` та `git show 1145e1f:backend/app/services/meal_plan_service.py`. Не перемикати робочу копію і не видаляти поточні зміни. |
| 2 | UML до | `docs/lab12/architecture_before.md`, відрендерований Mermaid-блок; джерело `before.mmd`. |
| 3 | Код Facade | `backend/app/services/meal_planning_facade.py`: конструктор і чотири сценарії, `_recipe_weeks`; особливо transaction + synchronize. |
| 4 | UML Facade | Відрендерені блоки `docs/lab12/architecture_after.md`; джерела `after_facade.mmd`, `facade_sequence.mmd`. |
| 5 | Код другого патерна | Не потрібний: другий патерн не впроваджувався; показати обґрунтування в `patterns_justification.md`. |
| 6 | UML другого патерна | Не потрібна; не позначати існуючі патерни як нові. |
| 7 | Нові тести | `backend/tests/test_meal_planning_facade.py`: порядок викликів, rollback усіх записів, ізоляція та два тижні. |
| 8 | Результати | `Get-Content docs/lab12/logs/after/backend_all.txt -Tail 8`; `Get-Content docs/lab12/logs/after/flutter_analyze.txt`; `test_results.md` і counts.json; для живого Flutter-термінала runner або `flutter test --reporter expanded`. |
| 9 | Незмінна функціональність | Android: деталі тестового рецепта → план із 0.5/2 порціями → добові калорії й діаграма → автоматичні покупки після зміни порцій; UI має лишитися тим самим. |
| 10 | Git і порівняння | `git branch --show-current`, `git status --short`; `docs/lab12/logs/contract_comparison.json` з рівними SQL-лічильниками й OpenAPI. |

Це перелік для підготовки скріншотів, не твердження, що всі вони вже зроблені. Ручна Android-демонстрація під час цього етапу NOT RUN.

## Коротка демонстрація на захисті

1. Показати проблему в старих RecipeService.save/delete і MealPlanService.assign/delete через `git show 1145e1f:...`, UML до та після.
2. Відкрити новий фасад і Depends у `backend/app/dependencies.py`; показати один Session і послідовність перевірка → запис → sync → commit. Пояснити rollback при помилці й збереження owner checks.
3. Показати 16 нових тестів і фактичні 154 backend PASS; пояснити Flutter SKIP через відсутність окремого live API. Запуск повного набору: команда runner у test_results.md.
4. Для ручної демонстрації використовувати окремий тестовий акаунт. Запустити backend зі звичним налаштованим середовищем і Flutter з основною точкою входу; команди нижче. Не виконувати seed повторно без потреби.
5. Створити власний тестовий рецепт на 2 порції: 320 ккал/порцію, яйця 4 шт, молоко 100 мл. Запланувати 0.5 порції: 160 ккал, яйця 1 шт, молоко 25 мл. Змінити на 2 порції: 640 ккал, яйця 4 шт, молоко 100 мл. Перевірити поточний тиждень у покупках і статистиці.
6. Змінити інгредієнти рецепта й показати синхронізацію; ручний продукт має зберегтися. Для перевірки відкату показати автоматизований тест, а не ламати робочий сервер.

Backend в окремому PowerShell (існуючі .env і міграції вже налаштовані):

```powershell
Set-Location 'D:\IPZ-43\App\backend'
.\.venv\Scripts\python.exe -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000 --reload
```

Flutter:

```powershell
Set-Location 'D:\IPZ-43\App'
flutter devices
flutter run -d emulator-5554 -t lib/main.dart
```

Підставити фактичний ID Android-емулятора. Для чистого тестового серверного середовища використати окремий MEALMATE_DATABASE_URL та попередньо `alembic upgrade head`, як описано у backend/README.md. Паролі, JWT і секрети не показувати на скріншотах.
