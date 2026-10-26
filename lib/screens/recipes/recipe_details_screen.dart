import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/recipe_service.dart';
import 'add_edit_recipe_screen.dart';
import '../../widgets/recipes/preparation_step_tile.dart';
import '../../widgets/recipes/recipe_artwork.dart';
import '../../widgets/recipes/recipe_ingredient_tile.dart';

class RecipeDetailsScreen extends StatelessWidget {
  const RecipeDetailsScreen({
    required this.service,
    required this.recipeId,
    super.key,
  });
  final RecipeService service;
  final String recipeId;

  void _edit(BuildContext context) {
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            AddEditRecipeScreen(service: service, recipeId: recipeId),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final recipe = service.findById(recipeId);
    if (recipe == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Видалити рецепт?'),
        content: Text('Цю дію неможливо скасувати.\n\n«${recipe.name}»'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await service.deleteAsync(recipeId);
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final recipe = service.findById(recipeId);
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Рецепт не знайдено')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => Navigator.pop(context)),
            title: const Text('Деталі рецепта'),
            actions: [
              IconButton(
                tooltip: 'Редагувати рецепт',
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: RecipeArtwork(category: recipe.category, size: 112),
                ),
                const SizedBox(height: 20),
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.category.label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  recipe.description,
                  style: const TextStyle(color: AppColors.muted, height: 1.6),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text('${recipe.preparationMinutes} хв'),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.local_fire_department_outlined,
                        size: 18,
                      ),
                      label: Text(
                        recipe.calories == null
                            ? 'Калорійність не вказана'
                            : '${recipe.calories} ккал / порція',
                      ),
                    ),
                    if (recipe.servings != null)
                      Chip(
                        avatar: const Icon(Icons.restaurant_outlined, size: 18),
                        label: Text('Порцій: ${recipe.servings}'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Інгредієнти',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < recipe.ingredients.length;
                          index++
                        ) ...[
                          if (index > 0) const Divider(height: 1),
                          RecipeIngredientTile(
                            ingredient: recipe.ingredients[index],
                          ),
                        ],
                        if (recipe.ingredients.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Інгредієнти не вказані'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Приготування',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                for (
                  var index = 0;
                  index < recipe.preparationSteps.length;
                  index++
                )
                  PreparationStepTile(
                    number: index + 1,
                    text: recipe.preparationSteps[index],
                  ),
                if (recipe.preparationSteps.isEmpty)
                  const Text('Інструкція ще не додана'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Редагувати'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Видалити рецепт'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
