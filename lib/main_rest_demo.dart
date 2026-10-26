import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'demo/rest/recipe_api_client.dart';
import 'demo/rest/rest_demo_screen.dart';

void main() {
  // Демонстрація доступна тільки окремою debug-точкою входу.
  runApp(kDebugMode ? const RestDemoApp() : const MealMateApp());
}

class RestDemoApp extends StatefulWidget {
  const RestDemoApp({super.key});
  @override
  State<RestDemoApp> createState() => _RestDemoAppState();
}

class _RestDemoAppState extends State<RestDemoApp> {
  late final RecipeApiClient _client = RecipeApiClient(
    baseUrl: Uri.parse(
      const String.fromEnvironment(
        'REST_BASE_URL',
        defaultValue: 'http://10.0.2.2:8080',
      ),
    ),
  );
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MealMate REST demo',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('uk'),
    supportedLocales: const [Locale('uk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: RestDemoScreen(client: _client),
  );
}
