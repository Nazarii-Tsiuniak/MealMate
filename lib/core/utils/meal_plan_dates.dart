abstract final class MealPlanDates {
  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  // Календарні дні замість Duration: переходи літнього часу не зсувають дату.
  static DateTime shift(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);
  static DateTime monday(DateTime date) => shift(day(date), 1 - date.weekday);
  static const weekdays = [
    'Понеділок',
    'Вівторок',
    'Середа',
    'Четвер',
    'П’ятниця',
    'Субота',
    'Неділя',
  ];
  static const shortWeekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
  static const months = [
    'січня',
    'лютого',
    'березня',
    'квітня',
    'травня',
    'червня',
    'липня',
    'серпня',
    'вересня',
    'жовтня',
    'листопада',
    'грудня',
  ];
  static String label(DateTime date) =>
      '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  static String weekLabel(DateTime start) {
    final end = shift(start, 6);
    final first = start.month == end.month
        ? '${start.day}'
        : '${start.day} ${months[start.month - 1]}${start.year != end.year ? ' ${start.year}' : ''}';
    return '$first–${end.day} ${months[end.month - 1]} ${end.year}';
  }
}
