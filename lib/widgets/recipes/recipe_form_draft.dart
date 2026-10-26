import 'package:flutter/material.dart';

import '../../models/recipe_ingredient.dart';

/// Контролери редагованих рядків належать лише формі, не сховищу.
class IngredientDraft {
  IngredientDraft([RecipeIngredient? source])
    : name = TextEditingController(text: source?.name ?? ''),
      quantity = TextEditingController(
        text: source?.quantity == null
            ? ''
            : source!.quantity.toString().replaceAll(RegExp(r'\.0$'), ''),
      ),
      unit = source?.unit?.replaceAll('.', ''),
      toTaste = source != null && source.quantity == null;

  final TextEditingController name;
  final TextEditingController quantity;
  String? unit;
  bool toTaste;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class StepDraft {
  StepDraft([String text = ''])
    : controller = TextEditingController(text: text);
  final TextEditingController controller;
  void dispose() => controller.dispose();
}
