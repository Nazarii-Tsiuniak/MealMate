import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';
import 'recipe_artwork.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({required this.recipe, required this.onTap, super.key});
  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      recipe.category.label,
      '${recipe.preparationMinutes} хв',
      if (recipe.calories != null) '${recipe.calories} ккал',
    ].join(' · ');
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE0E6E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              RecipeArtwork(category: recipe.category),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
