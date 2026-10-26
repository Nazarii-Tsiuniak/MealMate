import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe_ingredient.dart';

class RecipeIngredientTile extends StatelessWidget {
  const RecipeIngredientTile({required this.ingredient, super.key});
  final RecipeIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(ingredient.name)),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              ingredient.amountLabel,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
