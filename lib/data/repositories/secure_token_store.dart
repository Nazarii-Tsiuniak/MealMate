import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../repositories/token_store.dart';

/// Android Keystore: зберігаємо лише JWT, ніколи пароль.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static const _key = 'mealmate_access_token';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}
