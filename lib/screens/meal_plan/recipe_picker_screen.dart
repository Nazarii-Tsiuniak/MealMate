import 'package:flutter/material.dart';

import '../../services/recipe_service.dart';
import '../../widgets/recipes/recipe_card.dart';

/// Показує актуальне джерело через сервіс, без власної копії каталогу.
class RecipePickerScreen extends StatefulWidget {
  const RecipePickerScreen({required this.recipes, super.key});
  final RecipeService recipes;
  @override
  State<RecipePickerScreen> createState() => _RecipePickerScreenState();
}

class _RecipePickerScreenState extends State<RecipePickerScreen> {
  final _search = TextEditingController();
  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Вибрати рецепт')),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: widget.recipes,
        builder: (context, _) {
          final results = widget.recipes.recipes
              .where(
                (recipe) =>
                    _normalize(recipe.name).contains(_normalize(_search.text)),
              )
              .toList();
          // Пошук теж прокручується: клавіатура не перекриває результати
          // навіть у горизонтальній орієнтації та з великим шрифтом.
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    key: const ValueKey('plan-recipe-search'),
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Пошук рецептів',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Очистити пошук',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
              ),
              if (results.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      widget.recipes.recipes.isEmpty
                          ? 'Поки немає рецептів. Додайте рецепт у каталозі.'
                          : 'Рецептів не знайдено',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RecipeCard(
                        recipe: results[index],
                        onTap: () => Navigator.pop(context, results[index].id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
