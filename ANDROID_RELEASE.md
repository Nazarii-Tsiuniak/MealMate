# MealMate Offline — підписаний Android release

Offline applicationId: `com.example.mealmate.offline`. Server applicationId: `com.example.mealmate`. Назва та іконки обох залишаються MealMate. Типовий flavor — server, тому звичайний серверний запуск не змінює ID.

Offline flavor потребує явного `--target lib/main_offline.dart`; неправильна точка входу зупиняє збірку. Release не використовує debug-ключ. Без приватного PKCS12 keystore і змінних підписування release зупиняється з поясненням.

## 1. Створення ключа власником

Поки release-ключа немає. Ці команди власник виконує сам у PowerShell. Не додавайте `-storepass` або пароль до команди, файлу чи чату:

```powershell
Set-Location 'D:\IPZ-43\App'
$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
$releaseKey = Join-Path $env:USERPROFILE '.android\mealmate-offline-release.p12'
if (Test-Path -LiteralPath $releaseKey) { throw 'Keystore already exists. Do not overwrite it.' }
& $keytool -genkeypair -keystore $releaseKey -storetype PKCS12 -alias mealmate-offline -keyalg RSA -keysize 3072 -sigalg SHA256withRSA -validity 10000
```

Keytool запросить пароль із підтвердженням без відображення введення та дані власника сертифіката. Використайте власний стійкий пароль. Для цього PKCS12 пароль приватного ключа збігається з паролем сховища.

## 2. Збірка після створення ключа

```powershell
.\tool\build_offline_release.ps1
```

Скрипт запитує пароль через Read-Host -AsSecureString, передає його Gradle лише через середовище поточного процесу та відновлює попереднє середовище після завершення. Пароль не записується у вихідний код, файл properties або командний рядок. Не запускайте скрипт із трасуванням/журналюванням змінних середовища.

Команда збірки всередині скрипта:

```powershell
flutter build apk --release --flavor offline --target lib/main_offline.dart
```

Очікуваний шлях після успішної збірки: `build/app/outputs/flutter-apk/app-offline-release.apk`. До створення ключа файла з підписаним offline release немає; розмір та підпис потрібно перевірити після фактичної збірки.

Версія з поточного pubspec: versionName `1.0.0`, versionCode `1`. Для наступних оновлень збільшуйте versionCode і підписуйте тим самим ключем.

## 3. Збереження ключа й даних

Збережіть щонайменше дві захищені резервні копії `.p12` поза репозиторієм, наприклад на зашифрованому зовнішньому носії. Пароль — окремо в менеджері паролів. Також збережіть alias `mealmate-offline`. Втрата ключа або пароля не дозволить звичайне оновлення цієї APK-інсталяції тим самим applicationId.

`.p12`, `.pfx`, `.jks`, `.keystore`, локальні signing properties та каталог android/signing виключені з Git. Ключа й парольних файлів агент не створює.

Новий offline applicationId означає окреме Android-сховище: дані з наявної debug/server-інсталяції самі не переносяться. Перед встановленням збережіть JSON-копію через профіль старої версії, потім імпортуйте її в новій. Не видаляйте старий застосунок для встановлення нового — різні ID можуть співіснувати.

## 4. Дозволи та запуск

Offline release manifest прибирає INTERNET та ACCESS_NETWORK_STATE, забороняє cleartext HTTP. JSON працює через системний Android Storage Access Framework без широких дозволів читання/запису сховища. Debug зберігає мережеві можливості Flutter tooling; це не залежність основних офлайн-функцій.

```powershell
flutter run --flavor offline -d emulator-5554 -t lib/main_offline.dart
flutter run --flavor server -d emulator-5554 -t lib/main.dart
```

Не запускайте offline entrypoint із server flavor для встановлення окремого офлайн-застосунку. Старі команди в інших документах без --flavor використовуватимуть server за замовчуванням.

## 5. Перевірки перед передаванням APK

`flutter analyze` та `flutter test`; перевірка merged release manifest, applicationId/версій; `apksigner verify --verbose --print-certs` для готового APK. Сертифікат має бути вашим, не Android Debug. APK на телефон автоматично не встановлюється.
