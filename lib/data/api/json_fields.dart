abstract final class JsonFields {
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Очікується об’єкт JSON');
    }
    return value;
  }

  static List<dynamic> list(Object? value) {
    if (value is! List) throw const FormatException('Очікується масив JSON');
    return value;
  }

  static String text(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Очікується текст');
    }
    return value;
  }

  static String uuid(Object? value) {
    final v = text(value);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(v)) {
      throw const FormatException('Некоректний UUID');
    }
    return v;
  }

  static double number(Object? value) {
    if (value is! num || !value.isFinite) {
      throw const FormatException('Очікується скінченне число');
    }
    return value.toDouble();
  }

  static int integer(Object? value) {
    if (value is! int) throw const FormatException('Очікується ціле число');
    return value;
  }

  static bool boolean(Object? value) {
    if (value is! bool) {
      throw const FormatException('Очікується логічне значення');
    }
    return value;
  }

  static DateTime date(Object? value) {
    final textValue = text(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(textValue)) {
      throw const FormatException('Некоректна дата');
    }
    final result = DateTime.parse(textValue);
    if (dateText(result) != textValue) {
      throw const FormatException('Некоректна дата');
    }
    return result;
  }

  static String dateText(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
