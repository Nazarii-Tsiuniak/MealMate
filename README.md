# MealMate

Навчальний мобільний застосунок для **Android**: рецепти, планування харчування, автоматичні покупки та облік запланованих калорій. Інтерфейс українською, світлий мінімалістичний дизайн із темно-зеленими акцентами.

## Технології та архітектура

- Flutter + Dart, Material Design, Visual Studio Code.
- Python + FastAPI, Pydantic, SQLAlchemy, SQLite, Alembic.
- JWT Bearer та Argon2id; JWT у захищеному Android Keystore-сховищі.
- Flutter: UI → Service → Repository → DTO / API client.
- Backend: Router → Service → Repository → Database.

## Основні функції

- Реєстрація, вхід, профіль, відновлення сесії та вихід.
- Каталог, пошук, категорії, деталі, створення, редагування й видалення рецептів.
- Сніданок, обід і вечеря за датами; перемикання тижнів і дробові порції.
- Автоматичне об’єднання інгредієнтів у покупках, ручні позиції та позначки придбання.
- Ккал дня й кожного прийому їжі, власна денна ціль, тижнева діаграма та неповні підсумки для невідомих ккал.
- Серверне збереження та ізоляція даних різних акаунтів.

Основний режим — серверний. Помилки мережі не перемикають застосунок на демодані. Нижня навігація має чотири вкладки: Головна, Рецепти, План, Покупки; профіль відкривається через аватар.

## Завантаження

```powershell
git clone https://github.com/Nazarii-Tsiuniak/MealMate.git
cd MealMate
```

Наявна робоча копія автора: `D:\IPZ-43\App`. Далі команди виконуються від кореня проєкту. Потрібні Flutter з Android SDK та Python 3.11+; перевірено з Flutter 3.47.6 і Python 3.13.7.

## FastAPI, SQLite та міграції

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
```

Лише під час першого налаштування створіть локальний `.env` із випадковим секретом. Команда відмовиться перезаписати наявний файл:

```powershell
.\.venv\Scripts\python.exe -c "import secrets; from pathlib import Path; Path('.env').open('x', encoding='utf-8').write('MEALMATE_JWT_SECRET=' + secrets.token_hex(32) + '\nMEALMATE_DATABASE_URL=sqlite:///./data/mealmate.db\nMEALMATE_ACCESS_TOKEN_MINUTES=30\n')"
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000 --reload
```

Swagger UI: http://127.0.0.1:8000/docs. Не змінюйте секрет між звичайними перезапусками. SQLite та .env виключені з Git: клон починає з чистої бази після міграцій. Докладніше: [backend/README.md](backend/README.md).

## Flutter на Android-емуляторі

В іншому терміналі поверніться до кореня проєкту, запустіть емулятор через VS Code / Android Studio:

```powershell
flutter pub get
flutter devices
flutter run -d emulator-5554 -t lib/main.dart
```

Підставте свій ID, якщо він інший. Android-емулятор звертається до комп’ютера через `http://10.0.2.2:8000/api/v1`.

Створіть акаунт через «Зареєструватися», потім увійдіть. Пароль застосунок локально не зберігає. Каталог нового акаунта порожній до створення власних рецептів або явного запуску seed.

## 10 готових рецептів для демонстрації

У третьому терміналі після реєстрації користувача:

```powershell
cd backend
.\.venv\Scripts\python.exe -m scripts.seed_recipes --user-email "your-email@example.com" --dry-run
.\.venv\Scripts\python.exe -m scripts.seed_recipes --user-email "your-email@example.com"
```

Вкажіть email свого наявного акаунта. Seed додає 10 повних рецептів із розрахованою орієнтовною калорійністю й не змінює користувачів, власні рецепти, план або покупки. Повторний запуск не дублює дані. Увесь запис виконується однією транзакцією. Автоматично при запуску FastAPI він не виконується.

[Перелік страв, порції, калорії, припущення й правила seed](backend/SEED_RECIPES.md). Якщо ви вже мали власний «Омлет», після наповнення буде 11 рецептів. Поверніть застосунок із фону або перезапустіть його для оновлення каталогу.

## Сценарій для викладача

1. Запустіть FastAPI та Flutter, увійдіть до наповненого акаунта.
2. Покажіть каталог, пошук і деталі страви з інгредієнтами та кроками.
3. Додайте «Омлет із сиром та помідорами» до плану: одна порція — приблизно 325 ккал; дві — 650; половина — 162,5.
4. Відкрийте покупки: кількості залежать від запланованих порцій. Додайте ручний продукт, позначте його придбаним, змініть порції та покажіть оновлення.
5. У профілі змініть ціль калорій, покажіть денний прогрес і тижневу діаграму.
6. Перезапустіть застосунок і сервер із тим самим .env/SQLite: рецепти й план зберігаються. Ваш початковий «Омлет» лишається окремим рецептом.

## Тести

```powershell
flutter analyze
flutter test
.\backend\.venv\Scripts\python.exe tool/run_backend_integration.py

cd backend
$testBase = Join-Path $env:TEMP ('mealmate-tests-' + [guid]::NewGuid().ToString('N'))
.\.venv\Scripts\python.exe -m pytest -q --basetemp=$testBase
```

Live-тест самостійно запускає тимчасовий FastAPI з окремою тестовою базою; звичайний `flutter test` пропускає лише цей сценарій без MEALMATE_LIVE_API. Наявні тести збережено. Поточний результат: `flutter analyze` без зауважень, 125 Flutter-тестів успішні (1 live-сценарій пропускається у стандартному наборі), 115 backend-тестів успішні. Додано 6 seed-тестів.

## Документація та режими

- [Інтеграція Flutter, перевірки й обмеження](SERVER_INTEGRATION.md).
- [Backend API та Swagger](backend/README.md).
- [Демонстраційні рецепти й seed](backend/SEED_RECIPES.md).
- [Окремий REST-модуль лабораторної](REST_DEMO.md).
- [Попередній етап калорій](CALORIES_STAGE1.md).
- [Попередня комплексна перевірка](QA_REPORT.md).

`flutter run -d emulator-5554 -t lib/main_demo.dart` — окремий локальний режим зі стрічкою «ДЕМО». Його дані не переносяться на сервер. Основний запуск — `lib/main.dart`.

Сервер має бути доступний; офлайн-редагування та refresh token поки не реалізовані. Автоматичні покупки змінюються через рецепти/план. Докладні обмеження наведено в SERVER_INTEGRATION.md.
