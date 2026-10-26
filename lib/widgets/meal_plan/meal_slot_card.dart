import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/meal_plan.dart';
import '../../models/recipe.dart';
import '../../services/nutrition_service.dart';
import '../recipes/recipe_card.dart';

class MealSlotCard extends StatelessWidget {
  const MealSlotCard({
    required this.type,
    required this.recipe,
    required this.onChoose,
    required this.onRemove,
    this.plannedServings = 1,
    this.calories,
    this.onServings,
    super.key,
  });
  final MealType type;
  final double plannedServings;
  final double? calories;
  final VoidCallback? onServings;
  final Recipe? recipe;
  final VoidCallback onChoose;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              type.time,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                type.label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (recipe == null)
          OutlinedButton.icon(
            key: ValueKey('add-${type.name}'),
            onPressed: onChoose,
            icon: const Icon(Icons.add),
            label: const Text('Додати страву · 0 ккал'),
          )
        else ...[
          RecipeCard(recipe: recipe!, onTap: onChoose),
          const SizedBox(height: 8),
          Text(
            calories == null
                ? 'Калорійність не вказана'
                : '${NutritionService.number(calories!)} ккал за прийом їжі',
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                key: ValueKey('servings-${type.name}'),
                onPressed: onServings,
                child: Text(
                  'Порцій: ${NutritionService.number(plannedServings)}',
                ),
              ),
              TextButton.icon(
                key: ValueKey('replace-${type.name}'),
                onPressed: onChoose,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Замінити'),
              ),
              IconButton(
                key: ValueKey('remove-${type.name}'),
                onPressed: onRemove,
                tooltip: 'Прибрати: ${type.label}',
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
