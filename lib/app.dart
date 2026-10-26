import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/secure_token_store.dart';
import 'demo_app.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/server_workspace.dart';
import 'services/auth_service.dart';

class MealMateApp extends StatelessWidget {
  const MealMateApp({this.demo = false, this.auth, super.key});
  final bool demo;
  final AuthService? auth;
  @override
  Widget build(BuildContext context) =>
      demo ? const MealMateDemoApp() : _ServerApp(auth: auth);
}

class _ServerApp extends StatefulWidget {
  const _ServerApp({this.auth});
  final AuthService? auth;
  @override
  State<_ServerApp> createState() => _ServerAppState();
}

class _ServerAppState extends State<_ServerApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final AuthService _auth;
  bool _hadUser = false;
  @override
  void initState() {
    super.initState();
    _auth =
        widget.auth ??
        AuthService(AuthRepository(ApiClient()), const SecureTokenStore());
    _hadUser = _auth.user != null;
    _auth.addListener(_changed);
    if (_auth.user == null) unawaited(_auth.restore());
  }

  void _changed() {
    if (_hadUser && _auth.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigator.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.login,
            (_) => false,
          );
        }
      });
    }
    _hadUser = _auth.user != null;
  }

  @override
  void dispose() {
    _auth.removeListener(_changed);
    if (widget.auth == null) {
      _auth.repository.api.close();
      _auth.dispose();
    }
    super.dispose();
  }

  Widget _gate(BuildContext context) => ListenableBuilder(
    listenable: _auth,
    builder: (context, _) {
      if (_auth.restoring) {
        return const Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('MealMate'),
                  SizedBox(height: 20),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      }
      if (_auth.error != null && _auth.user == null) {
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
                    Text(_auth.error!),
                    TextButton(
                      onPressed: _auth.restore,
                      child: const Text('Повторити'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (_auth.user == null) return LoginScreen(auth: _auth);
      return ServerWorkspace(key: ValueKey(_auth.user!.id), auth: _auth);
    },
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: 'MealMate',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('uk'),
    supportedLocales: const [Locale('uk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    initialRoute: AppRoutes.login,
    routes: {
      AppRoutes.login: _gate,
      AppRoutes.home: _gate,
      AppRoutes.register: (_) => RegisterScreen(auth: _auth),
    },
  );
}
