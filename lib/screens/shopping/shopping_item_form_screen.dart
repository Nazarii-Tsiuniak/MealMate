import 'package:flutter/material.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../models/recipe_ingredient.dart';
import '../../models/shopping_item.dart';
import '../../services/recipe_validation.dart';
import '../../services/shopping_list_service.dart';

class ShoppingItemFormScreen extends StatefulWidget {
  const ShoppingItemFormScreen({
    required this.service,
    required this.week,
    this.item,
    super.key,
  });
  final ShoppingListService service;
  final DateTime week;
  final ShoppingItem? item;
  @override
  State<ShoppingItemFormScreen> createState() => _ShoppingItemFormScreenState();
}

class _ShoppingItemFormScreenState extends State<ShoppingItemFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _quantity;
  String? _unit;
  late ShoppingCategory _category;
  late bool _toTaste;
  bool _saving = false;
  bool get _editing => widget.item != null;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.ingredientName ?? '');
    _quantity = TextEditingController(
      text:
          widget.item?.quantity
              ?.toString()
              .replaceAll(RegExp(r'\.0$'), '')
              .replaceAll('.', ',') ??
          '',
    );
    _unit = widget.item?.unit;
    _category = widget.item?.category ?? ShoppingCategory.other;
    _toTaste = _editing && widget.item!.quantity == null;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final quantity = _toTaste ? null : RecipeValidation.decimal(_quantity.text);
    try {
      if (_editing) {
        await widget.service.updateManualAsync(
          week: widget.week,
          id: widget.item!.id,
          quantity: quantity,
          unit: _toTaste ? null : _unit,
        );
      } else {
        await widget.service.addManualAsync(
          week: widget.week,
          name: _name.text,
          quantity: quantity,
          unit: _toTaste ? null : _unit,
          category: _category,
        );
      }
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      setState(() => _saving = false);
      _error(error.message.toString());
    } on StateError catch (error) {
      setState(() => _saving = false);
      _error(error.message);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _error(e.toString());
      }
    }
  }

  void _error(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_editing ? 'Змінити кількість' : 'Додати продукт'),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saving) const LinearProgressIndicator(),
              Text(MealPlanDates.weekLabel(widget.week)),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('shopping-name'),
                controller: _name,
                readOnly: _editing,
                validator: RecipeValidation.requiredText,
                decoration: const InputDecoration(labelText: 'Назва продукту'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('За смаком'),
                value: _toTaste,
                onChanged: (value) => setState(() => _toTaste = value),
              ),
              if (!_toTaste) ...[
                TextFormField(
                  key: const ValueKey('shopping-quantity'),
                  controller: _quantity,
                  validator: RecipeValidation.quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Кількість'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('shopping-unit'),
                  initialValue: _unit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Одиниця вимірювання',
                  ),
                  items: [
                    for (final unit in RecipeIngredient.units)
                      DropdownMenuItem(value: unit, child: Text(unit)),
                  ],
                  onChanged: (value) => _unit = value,
                  validator: (value) =>
                      value == null ? 'Оберіть одиницю' : null,
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<ShoppingCategory>(
                key: const ValueKey('shopping-category'),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Категорія'),
                items: [
                  for (final category in ShoppingCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: _editing ? null : (value) => _category = value!,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('save-shopping-item'),
                onPressed: _saving ? null : _save,
                child: Text(_editing ? 'Зберегти зміни' : 'Додати продукт'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
