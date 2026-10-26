import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_shell.dart';
import 'services/recipe_service.dart';
import 'services/nutrition_settings_service.dart';
import 'services/meal_plan_service.dart';
import 'services/shopping_list_service.dart';

class MealMateDemoApp extends StatefulWidget {
  const MealMateDemoApp({super.key});
  @override
  State<MealMateDemoApp> createState() => _MealMateDemoAppState();
}

class _MealMateDemoAppState extends State<MealMateDemoApp> {
  // Одне сховище на весь поточний запуск. Перезапуск відновлює демо-дані.
  final _recipes = RecipeService.demo();
  final _nutritionSettings = NutritionSettingsService();
  late final MealPlanService _mealPlans;
  late final ShoppingListService _shopping;

  @override
  void initState() {
    super.initState();
    _mealPlans = MealPlanService.inMemory(_recipes);
    _shopping = ShoppingListService.inMemory(_mealPlans);
  }

  @override
  void dispose() {
    _nutritionSettings.dispose();
    _shopping.dispose();
    _mealPlans.dispose();
    _recipes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MealMate',
      builder: (context, child) => Banner(
        message: 'ДЕМО',
        location: BannerLocation.topEnd,
        child: child!,
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('uk'),
      supportedLocales: const [Locale('uk')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.home: (_) => MainShell(
          service: _recipes,
          mealPlans: _mealPlans,
          shoppingList: _shopping,
          nutritionSettings: _nutritionSettings,
        ),
        AppRoutes.register: (_) => const RegisterScreen(),
      },
    );
  }
}
