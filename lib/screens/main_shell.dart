import 'package:flutter/material.dart';

import '../widgets/main_navigation_bar.dart';
import '../services/auth_service.dart';
import '../services/nutrition_settings_service.dart';
import 'profile/profile_screen.dart';
import '../services/recipe_service.dart';
import '../services/meal_plan_service.dart';
import '../services/shopping_list_service.dart';
import 'shopping/shopping_list_screen.dart';
import 'meal_plan/meal_plan_screen.dart';
import 'home/home_screen.dart';
import 'recipes/recipes_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialIndex = 0,
    this.service,
    this.mealPlans,
    this.shoppingList,
    this.nutritionSettings,
    this.auth,
    this.statusBanner,
  }) : assert(initialIndex >= 0 && initialIndex < 4);
  final AuthService? auth;
  final Widget? statusBanner;
  final int initialIndex;
  final RecipeService? service;
  final MealPlanService? mealPlans;
  final ShoppingListService? shoppingList;
  final NutritionSettingsService? nutritionSettings;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;
  late final RecipeService _recipes;
  late final MealPlanService _mealPlans;
  late final ShoppingListService _shopping;
  late final NutritionSettingsService _nutritionSettings;
  final _planKey = GlobalKey<MealPlanScreenState>();
  void _openTodayPlan() {
    _planKey.currentState?.showDate(DateTime.now());
    _select(2);
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _nutritionSettings = widget.nutritionSettings ?? NutritionSettingsService();
    _recipes =
        widget.service ??
        widget.mealPlans?.recipes ??
        widget.shoppingList?.plans.recipes ??
        RecipeService.demo();
    _mealPlans =
        widget.mealPlans ??
        widget.shoppingList?.plans ??
        MealPlanService.inMemory(_recipes);
    _shopping = widget.shoppingList ?? ShoppingListService.inMemory(_mealPlans);
    assert(
      identical(_mealPlans.recipes, _recipes) &&
          identical(_shopping.plans, _mealPlans),
    );
  }

  @override
  void dispose() {
    if (widget.nutritionSettings == null) _nutritionSettings.dispose();
    if (widget.shoppingList == null) _shopping.dispose();
    if (widget.mealPlans == null && widget.shoppingList == null) {
      _mealPlans.dispose();
    }
    if (widget.service == null &&
        widget.mealPlans == null &&
        widget.shoppingList == null) {
      _recipes.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedIndex = index);
  }

  void _profile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ProfileScreen(settings: _nutritionSettings, auth: widget.auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (widget.statusBanner != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.25,
                  ),
                  child: SingleChildScrollView(child: widget.statusBanner!),
                ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    HomeScreen(
                      service: _mealPlans,
                      userName: widget.auth?.user?.name,
                      shopping: _shopping,
                      nutritionSettings: _nutritionSettings,
                      onPlan: _openTodayPlan,
                      onShopping: () => _select(3),
                      onProfile: _profile,
                    ),
                    RecipesScreen(service: _recipes),
                    MealPlanScreen(key: _planKey, service: _mealPlans),
                    ShoppingListScreen(service: _shopping),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MainNavigationBar(
          selectedIndex: _selectedIndex,
          onSelected: _select,
        ),
      ),
    );
  }
}
