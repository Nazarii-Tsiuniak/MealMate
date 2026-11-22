import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'data/local/local_storage_exception.dart';
import 'data/repositories/sqlite_local_profile_repository.dart';
import 'screens/main_shell.dart';
import 'services/local_profile_service.dart';
import 'services/recipe_service.dart';
import 'data/repositories/sqlite_recipe_repository.dart';
import 'data/repositories/sqlite_meal_plan_repository.dart';
import 'services/meal_plan_service.dart';
import 'data/repositories/sqlite_shopping_repository.dart';
import 'services/offline_shopping_service.dart';
import 'services/offline_backup_service.dart';
import 'widgets/offline_backup_actions.dart';

class MealMateOfflineApp extends StatefulWidget {
  const MealMateOfflineApp({this.database, super.key});
  final AppDatabase? database;
  @override
  State<MealMateOfflineApp> createState() => _MealMateOfflineAppState();
}

class _MealMateOfflineAppState extends State<MealMateOfflineApp> {
  late final AppDatabase _database;
  LocalProfileService? _profile;
  RecipeService? _recipes;
  MealPlanService? _plans;
  OfflineShoppingService? _shopping;
  SqliteShoppingRepository? _shoppingRepository;
  SqliteMealPlanRepository? _planRepository;
  SqliteRecipeRepository? _recipeRepository;
  OfflineBackupService? _backup;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    LocalProfileService? loadedProfile;
    try {
      final profile = await LocalProfileService.load(
        SqliteLocalProfileRepository(_database),
      );
      loadedProfile = profile;
      final repository = SqliteRecipeRepository(_database);
      await repository.initialize();
      final planRepository = SqliteMealPlanRepository(_database);
      await planRepository.load();
      final shoppingRepository = SqliteShoppingRepository(
        _database,
        repository,
        planRepository,
      );
      await shoppingRepository.load();
      repository.prepareCommit = shoppingRepository.prepareCommit;
      planRepository.prepareCommit = shoppingRepository.prepareCommit;
      final recipes = RecipeService(repository);
      final plans = MealPlanService(planRepository, recipes);
      final shopping = OfflineShoppingService(shoppingRepository, plans);
      if (!mounted) {
        shopping.dispose();
        plans.dispose();
        recipes.dispose();
        profile.dispose();
        return;
      }
      setState(() {
        _recipeRepository = repository;
        _recipes = recipes;
        _plans = plans;
        _shopping = shopping;
        _shoppingRepository = shoppingRepository;
        _planRepository = planRepository;
        _profile = profile;
        _backup = OfflineBackupService(
          _database,
          prepareCommit: shoppingRepository.prepareCommit,
          beforeAccess: () async {
            await repository.flushed;
            await planRepository.flushed;
            await shoppingRepository.flushed;
            await profile.flushed;
          },
          reload: () async {
            await repository.initialize();
            await planRepository.load();
            await shoppingRepository.load();
            await profile.reload();
          },
        );
      });
    } catch (error) {
      loadedProfile?.dispose();
      if (mounted) {
        setState(
          () => _error = error is LocalStorageException
              ? error.message
              : 'Не вдалося завантажити локальні дані. Спробуйте ще раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    final profile = _profile;
    profile?.dispose();
    _shopping?.dispose();
    _plans?.dispose();
    _recipes?.dispose();
    if (widget.database == null) {
      unawaited(_close(profile));
    }
    super.dispose();
  }

  Future<void> _close(LocalProfileService? profile) async {
    await profile?.flushed;
    await _recipeRepository?.flushed;
    await _planRepository?.flushed;
    await _shoppingRepository?.flushed;
    try {
      await _database.close();
    } catch (_) {
      /* Наступний запуск повторить відкриття. */
    }
  }

  Widget _content() {
    final profile = _profile;
    if (profile != null) {
      return ListenableBuilder(
        listenable: profile,
        builder: (context, _) => MainShell(
          service: _recipes!,
          mealPlans: _plans!,
          shoppingList: _shopping!,
          dataActions: OfflineBackupActions(service: _backup!),
          nutritionSettings: profile,
          localProfile: profile,
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('MealMate', style: TextStyle(fontSize: 26)),
                const SizedBox(height: 20),
                if (_loading) const CircularProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Повторити')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MealMate',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('uk'),
    supportedLocales: const [Locale('uk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _content(),
  );
}
