# MealMate — етап 4: Flutter ↔ FastAPI

## Що інтегровано

- Основний запуск `lib/main.dart` використовує серверний режим.
- Реєстрація, вхід, GET профілю, відновлення сесії, вихід і обробка 401.
- Каталог із серверним пошуком/категорією, деталі, створення, редагування та видалення рецептів.
- План за тижнями, призначення/заміна страви, дробові порції та видалення слота.
- Автоматичні покупки тільки з backend; ручне додавання/редагування/видалення, позначки придбання та групування.
- Статистика дня й тижня тільки з API; ціль зберігається PATCH `/users/me`.
- Індикатори запитів, повідомлення про помилки, повторне завантаження, захист від повторного натискання збереження.
- Чотири вкладки, тема, українські назви та компоненти попередніх етапів збережені.

## Контракт і архітектура

Зіставлено реальні файли `backend/app/schemas/{auth,user,recipe,meal_plan,shopping,statistics}.py`.
Використовується `snake_case`: preparation_minutes, preparation_steps, planned_servings, week_start, daily_calorie_goal. UUID передаються як рядки. Дати — `YYYY-MM-DD` без часу/UTC-перетворення. Тиждень починається з понеділка. Категорії й одиниці збігаються із серверними enum/Literal.

```text
UI → Service (async-операції) → API Repository → DTO/JSON → ApiClient → FastAPI
```

ApiClient — новий основний клієнт на Dart HttpClient. Він не імпортує REST-демонстрацію. Додає Bearer JWT, перевіряє статуси/JSON, має тайм-аути, не виконує автоматичних повторів POST/PUT/PATCH/DELETE й не передає JWT за HTTP-перенаправленням. Запізніла відповідь попередньої сесії не може оновити нову або завершити її.

Синхронні читання сервісів — знімки останніх підтверджених сервером даних для наявних UI-компонентів. Запис у серверному режимі відбувається асинхронно. Синхронні методи попереднього режиму залишені для ізольованих локальних репозиторіїв і наявних тестів; вони не виконують серверних змін.

ServerController координує оновлення каталогу, відкритих тижнів плану/покупок і статистики. Після серверної зміни повторно читає залежні ресурси. Кеші оновлюються узгодженим набором; UUID не накопичуються повторно. Кожен акаунт отримує окремий екземпляр сервісів. При виході/401 приватні маршрути й кеші прибираються.

У серверному ShoppingListService локальний генератор вимкнено. Backend сам підсумовує інгредієнти, враховує порції та статуси. Flutter не генерує паралельного списку.

DailyNutrition/WeeklyNutrition у серверному режимі отримують від API відомі ккал, повноту, ціль, індикатор/різницю та середнє. Невідомі ккал залишаються null. Розрахунки попереднього етапу працюють лише в явно обраному деморежимі.

## JWT і Android

Застосовано flutter_secure_storage 11.2.0 з AndroidOptions за замовчуванням. Зберігається лише access token, не пароль. Див. [опис Android Keystore та шифрування пакета](https://pub.dev/packages/flutter_secure_storage).

В AndroidManifest додано INTERNET для основного застосунку та allowBackup=false для захищеного сховища. Інші платформи не створювалися. Наявний debug Network Security Config дозволяє локальні HTTP-адреси 10.0.2.2/localhost. Для release потрібна HTTPS-адреса API; глобальний дозвіл незахищеного HTTP не додавався.

## Запуск backend на Windows

Перший запуск, якщо середовище ще не створено:

```powershell
cd D:\IPZ-43\App\backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
```

Створіть `.env` із випадковим секретом згідно з backend/README.md. Якщо `.env` уже є, залиште його: зміна ключа робить попередні JWT недійсними. Не додавайте секрет чи SQLite до Git.

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000 --reload
```

Swagger: http://127.0.0.1:8000/docs. Міграція лишається `0001`, нових міграцій цей етап не потребує.

## Запуск Android

Запустіть наявний емулятор у VS Code / Android Studio:

```powershell
cd D:\IPZ-43\App
flutter pub get
flutter devices
flutter run -d emulator-5554 -t lib/main.dart
```

За потреби задайте інший origin API:

```powershell
flutter run -d emulator-5554 -t lib/main.dart --dart-define=MEALMATE_API_URL=http://10.0.2.2:8000
```

Не додавайте `/api/v1` до параметра: клієнт формує цей префікс сам.

Локальний деморежим: `flutter run -d emulator-5554 -t lib/main_demo.dart`. Він позначений «ДЕМО» й відокремлений від серверних даних. `main_rest_demo.dart` та `lib/demo/rest/` не змінювалися.

## Ручна перевірка

1. Створіть акаунт у застосунку та увійдіть. Профіль і привітання мають показувати ваше ім’я. Неправильний пароль показує помилку, не відкриває головну.
2. Створіть рецепт: 320 ккал на порцію, вихід 2 порції, яйця 4 шт, молоко 100 мл, сіль за смаком, один крок. Перевірте каталог, пошук, категорію та деталі.
3. Додайте рецепт на сьогодні до сніданку з 0,5 порції: 160 ккал, 1 яйце та 25 мл молока. За 2 порцій — 640 ккал, 4 яйця та 100 мл.
4. Додайте рецепт до обіду/вечері: інгредієнти сумуються без дублікатів. Заміна й видалення слота оновлюють покупки та головну.
5. Позначте покупку придбаною, додайте ручний продукт, змініть порції. Ручний продукт залишається; змінена кількість автоматичного продукту скидає позначку.
6. У профілі встановіть ціль 500 ккал. За плану на 640 ккал буде перевищення 140 і повний індикатор. Перевірте тижневу діаграму та середнє за всі 7 днів.
7. Збережіть рецепт без калорійності: денний і тижневий підсумки мають бути позначені як неповні.
8. Змініть інгредієнти/вихід/калорії рецепта. Перевірте перерахунок. Видалення рецепта очищає його записи плану та автоматичні покупки.
9. Повністю закрийте застосунок без видалення й відкрийте знову. Сесія відновлюється; рецепти, порції, покупки та ціль зберігаються. Перезапустіть FastAPI з тим самим ключем/базою — дані також залишаються.
10. Вийдіть через профіль: JWT видаляється, «Назад» не відкриває приватні екрани. Увійдіть іншим акаунтом — попередніх даних немає.
11. Зупиніть FastAPI: відображається помилка. Відновіть сервер і натисніть «Повторити». Під час відновлення сесії мережева помилка зберігає токен для повторної спроби; 401 видаляє його та повертає до входу.

## Автоматизовані перевірки

```powershell
cd D:\IPZ-43\App
flutter analyze
flutter test
.\backend\.venv\Scripts\python.exe tool/run_backend_integration.py

cd backend
$testBase = Join-Path $env:TEMP ('mealmate-stage4-' + [guid]::NewGuid().ToString('N'))
.\.venv\Scripts\python.exe -m pytest -q --basetemp=$testBase
```

Звичайний Flutter-набір включає попередні тести плюс нові тести HTTP/JSON, авторизації, сховища через тестовий інтерфейс, сесії/навігації, тайм-ауту, старої відповіді сесії, серверних репозиторіїв та координатора. Попередні UI-тести явно обирають demo:true, щоб перевіряти свій попередній локальний сценарій; вони не видалені.

`server_live_test.dart` без MEALMATE_LIVE_API пропускається. `tool/run_backend_integration.py` запускає його з реальним тимчасовим FastAPI та окремою базою. Він перевіряє реєстрацію, вхід, CRUD, пошук, деталі, порції, покупки, ціль, тижневі ккал, відновлення сесії новим клієнтом і вихід. Основна база користувача не використовується.

Підсумкові перевірки:
- flutter analyze — No issues found.
- flutter test — 125 успішних тестів, 1 live-тест пропущений у стандартному наборі.
- tool/run_backend_integration.py — окремий live-тест успішний на реальному FastAPI.
- Backend — 109 тестів успішні.
- Фінальний основний Android debug APK успішно зібрано.
- На emulator-5554 (Pixel_7) перевірено запуск APK і нативне захищене сховище: запис, читання після примусового завершення процесу та видалення тестового ключа.
- Повний користувацький UI-сценарій із живим сервером на емуляторі не позначається як пройдений: його наведено для ручної перевірки. Серверні операції перевірені окремим реальним HTTP-тестом, а екрани й навігація — widget-тестами.

Під час перевірки не змінювалися налаштування клавіатури. Тестовий ключ Keystore окремий від JWT і видалений після перевірки. На емулятор повернуто основний застосунок.

## Відомі обмеження

- Сервер має бути доступний. Офлайн-редагування/черга синхронізації не реалізовані; помилка явно позначає останні показані дані як потенційно застарілі.
- Немає WebSocket/push синхронізації між пристроями. Власні зміни оновлюються одразу, зовнішні — при повторному завантаженні/поверненні застосунку на передній план.
- JWT має серверний строк дії, типово 30 хвилин. Refresh token відсутній; після 401 потрібен повторний вхід. Вихід видаляє локальний токен, але сервер не має списку відкликаних JWT.
- API видаляє лише ручні покупки. У серверному UI автоматичні продукти змінюються через план/рецепти; очищення з підтвердженням стосується ручних позицій. Для кількох ручних видалень немає серверної batch-транзакції.
- Після тайм-ауту запису результат може бути невідомим: клієнт не повторює POST автоматично. Перед повторним створенням перевірте каталог. Якщо запис підтверджений, але наступний GET не вдався, показується «Зміну збережено» із повтором лише завантаження.
- Backend має точність кількостей 6 десяткових знаків. Деталі в backend/README.md.
- Усі демодані попереднього запуску залишаються лише у деморежимі й не імпортуються автоматично до акаунта.

## Створені файли

- lib/core/utils/action_feedback.dart
- lib/data/api/api_client.dart
- lib/data/api/json_fields.dart
- lib/data/api/backend_json.dart
- lib/data/repositories/auth_repository.dart
- lib/data/repositories/secure_token_store.dart
- lib/data/repositories/api_recipe_repository.dart
- lib/data/repositories/api_meal_plan_repository.dart
- lib/data/repositories/api_shopping_repository.dart
- lib/data/repositories/api_nutrition_repository.dart
- lib/models/user_profile.dart
- lib/repositories/token_store.dart
- lib/services/auth_service.dart
- lib/services/server/server_controller.dart
- lib/services/server/server_services.dart
- lib/screens/server_workspace.dart
- lib/demo_app.dart
- lib/main_demo.dart
- test/server_auth_test.dart
- test/server_recipes_test.dart
- test/server_domain_test.dart
- test/server_session_screen_test.dart
- test/server_live_test.dart
- tool/run_backend_integration.py
- tool/android_storage_probe.dart
- SERVER_INTEGRATION.md

## Змінені файли

- pubspec.yaml, pubspec.lock
- android/app/src/main/AndroidManifest.xml
- lib/main.dart, lib/app.dart
- lib/services/recipe_service.dart
- lib/services/meal_plan_service.dart
- lib/services/shopping_list_service.dart
- lib/services/nutrition_service.dart
- lib/services/nutrition_settings_service.dart
- lib/screens/auth/login_screen.dart
- lib/screens/auth/register_screen.dart
- lib/screens/main_shell.dart
- lib/screens/home/home_screen.dart
- lib/screens/profile/profile_screen.dart
- lib/screens/recipes/recipes_screen.dart
- lib/screens/recipes/recipe_details_screen.dart
- lib/screens/recipes/add_edit_recipe_screen.dart
- lib/screens/meal_plan/meal_plan_screen.dart
- lib/screens/shopping/shopping_list_screen.dart
- lib/screens/shopping/shopping_item_form_screen.dart
- lib/widgets/auth/auth_layout.dart
- lib/widgets/home/calorie_goal_card.dart
- lib/widgets/shopping/shopping_item_tile.dart
- test/widget_test.dart
- test/auth_screens_test.dart
- test/qa_workflows_test.dart
- README.md
- backend/README.md

## Окрема нативна перевірка сховища

`tool/android_storage_probe.dart` — лише Android-перевірка тієї самої конфігурації Keystore з окремим тестовим ключем. Вона не читає й не змінює JWT.

```powershell
flutter run -d emulator-5554 -t tool/android_storage_probe.dart --no-resident
```

Перший запуск показує, що захищений запис збережено. Примусово закрийте й відкрийте застосунок: другий запуск має показати «Перезапуск: захищені дані відновлено й видалено». Потім поверніть основний застосунок:

```powershell
flutter run -d emulator-5554 -t lib/main.dart
```

Для нативної перевірки емулятор було запущено у фоновому режимі. Після повернення основного APK і перевірки екрана входу тестовий емулятор зупинено; відкрийте його у звичайному режимі через VS Code / Android Studio для ручної роботи. Наявний сервер користувача не зупинявся.
