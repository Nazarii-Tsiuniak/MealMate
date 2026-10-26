import 'package:flutter/material.dart';

import '../../models/recipe_ingredient.dart';
import 'recipe_form_draft.dart';
import '../../services/recipe_validation.dart';

class IngredientEditor extends StatelessWidget {
  const IngredientEditor({
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });
  final IngredientDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Інгредієнт ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Видалити інгредієнт ${index + 1}',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('ingredient-name-$index'),
              controller: draft.name,
              decoration: const InputDecoration(labelText: 'Назва інгредієнта'),
              validator: RecipeValidation.requiredText,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('За смаком'),
              value: draft.toTaste,
              onChanged: (value) {
                draft.toTaste = value;
                onChanged();
              },
            ),
            if (!draft.toTaste) ...[
              TextFormField(
                key: ValueKey('ingredient-quantity-$index'),
                controller: draft.quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Кількість'),
                validator: RecipeValidation.quantity,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: draft.unit,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Одиниця вимірювання',
                ),
                items: [
                  for (final unit in RecipeIngredient.units)
                    DropdownMenuItem(value: unit, child: Text(unit)),
                ],
                onChanged: (value) {
                  draft.unit = value;
                  onChanged();
                },
                validator: (value) => value == null ? 'Оберіть одиницю' : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
