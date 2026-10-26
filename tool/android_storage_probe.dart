// Лише перевірка Android Keystore. Не використовує й не змінює ключ JWT.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage(aOptions: AndroidOptions());
  const key = 'mealmate_native_storage_probe';
  const value = 'mealmate-native-test-value';
  String message;
  try {
    if (await storage.read(key: key) == value) {
      await storage.delete(key: key);
      if (await storage.read(key: key) != null) {
        throw StateError('Не видалено');
      }
      message = 'Перезапуск: захищені дані відновлено й видалено';
    } else {
      await storage.write(key: key, value: value);
      if (await storage.read(key: key) != value) {
        throw StateError('Не прочитано');
      }
      message = 'Захищений запис збережено. Перезапустіть застосунок';
    }
  } catch (_) {
    message = 'Помилка перевірки захищеного сховища';
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message),
            ),
          ),
        ),
      ),
    ),
  );
}
