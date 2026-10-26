/// Інгредієнт рецепта; без залежностей від UI або бази даних.
class RecipeIngredient {
  static const units = ['г', 'кг', 'мл', 'л', 'шт'];
  const RecipeIngredient({
    required this.name,
    this.quantity,
    this.unit,
    this.note,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final String? note;

  String get amountLabel {
    if (quantity == null) return note ?? 'за смаком';
    final value = quantity!;
    final number = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString().replaceAll('.', ',');
    return [number, if (unit != null) unit!, if (note != null) note!].join(' ');
  }
}
