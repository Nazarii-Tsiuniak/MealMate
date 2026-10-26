import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/recipe_service.dart';
import '../../models/recipe.dart';
import '../../widgets/recipes/recipe_card.dart';
import 'recipe_details_screen.dart';
import 'add_edit_recipe_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({required this.service, super.key});
  final RecipeService service;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  RecipeCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _createRecipe() async {
    FocusScope.of(context).unfocus();
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AddEditRecipeScreen(service: widget.service),
      ),
    );
    if (id != null && mounted) {
      await widget.service.query('', null);
      if (!mounted) return;
      // Після створення показуємо новий рецепт навіть за попереднього фільтра.
      setState(() {
        _search.clear();
        _category = null;
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) => _buildCatalog(context),
  );

  Widget _buildCatalog(BuildContext context) {
    final query = _normalize(_search.text);
    final recipes = widget.service.visibleRecipes
        .where(
          (recipe) =>
              (_category == null || recipe.category == _category) &&
              _normalize(recipe.name).contains(query),
        )
        .toList();

    return Scaffold(
      body: CustomScrollView(
        key: const PageStorageKey('recipes-catalog'),
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Мої рецепти',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Знайдіть щось смачне на сьогодні',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    key: const ValueKey('recipe-search'),
                    controller: _search,
                    onChanged: (_) {
                      setState(() {});
                      widget.service.query(_search.text, _category);
                    },
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Пошук рецептів',
                      hintStyle: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                      fillColor: const Color(0xFFF0F3EF),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.muted,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Очистити пошук',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(_search.clear);
                                widget.service.query('', _category);
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final category in [null, ...RecipeCategory.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category?.label ?? 'Усі'),
                        selected: _category == category,
                        onSelected: (_) {
                          setState(() => _category = category);
                          widget.service.query(_search.text, _category);
                        },
                        selectedColor: AppColors.lightGreen,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _category == category
                              ? Colors.transparent
                              : const Color(0xFFDDE5DE),
                        ),
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: _category == category
                              ? AppColors.primary
                              : AppColors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          if (recipes.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 42,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Рецептів не знайдено',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Спробуйте іншу назву або категорію.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RecipeCard(
                    recipe: recipes[index],
                    onTap: () async {
                      try {
                        await widget.service.loadDetails(recipes[index].id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                        return;
                      }
                      if (!context.mounted) return;
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailsScreen(
                            service: widget.service,
                            recipeId: recipes[index].id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      // Окрема зона резервує фактичну висоту кнопки й не перекриває список.
      // Під час введення пошуку звільняємо місце для результатів.
      bottomNavigationBar: View.of(context).viewInsets.bottom > 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                child: Align(
                  heightFactor: 1,
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton.extended(
                    onPressed: _createRecipe,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Додати рецепт',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
