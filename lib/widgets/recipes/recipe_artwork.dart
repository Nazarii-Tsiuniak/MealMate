import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';

/// Спільна тематична іконка для каталогу та деталей.
class RecipeArtwork extends StatelessWidget {
  const RecipeArtwork({required this.category, this.size = 58, super.key});
  final RecipeCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, background, foreground) = switch (category) {
      RecipeCategory.breakfast => (
        Icons.egg_outlined,
        const Color(0xFFFFEDBD),
        const Color(0xFFA77629),
      ),
      RecipeCategory.lunch => (
        Icons.soup_kitchen_outlined,
        AppColors.lightGreen,
        AppColors.primary,
      ),
      RecipeCategory.dinner => (
        Icons.ramen_dining_outlined,
        const Color(0xFFE7E0F3),
        const Color(0xFF795C99),
      ),
      RecipeCategory.salad => (
        Icons.auto_awesome_outlined,
        const Color(0xFFF4DEDA),
        const Color(0xFFB46655),
      ),
      RecipeCategory.dessert => (
        Icons.cake_outlined,
        const Color(0xFFF8E7D8),
        const Color(0xFF996842),
      ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size > 58 ? 26 : 16),
      ),
      child: Icon(icon, color: foreground, size: size * 28 / 58),
    );
  }
}
