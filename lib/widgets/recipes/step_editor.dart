import 'package:flutter/material.dart';

import 'recipe_form_draft.dart';
import '../../services/recipe_validation.dart';

class StepEditor extends StatelessWidget {
  const StepEditor({
    required this.draft,
    required this.index,
    required this.onRemove,
    super.key,
  });
  final StepDraft draft;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Крок ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Видалити крок ${index + 1}',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('recipe-step-$index'),
              controller: draft.controller,
              minLines: 2,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Що потрібно зробити?',
              ),
              validator: RecipeValidation.requiredText,
            ),
          ],
        ),
      ),
    );
  }
}
