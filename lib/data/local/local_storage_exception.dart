class LocalStorageException implements Exception {
  const LocalStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}
