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

