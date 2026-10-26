import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/server/server_controller.dart';
import 'main_shell.dart';

class ServerWorkspace extends StatefulWidget {
  const ServerWorkspace({required this.auth, super.key});
  final AuthService auth;
  @override
  State<ServerWorkspace> createState() => _ServerWorkspaceState();
}

class _ServerWorkspaceState extends State<ServerWorkspace>
    with WidgetsBindingObserver {
  late final ServerController _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ServerController(widget.auth);
    unawaited(_controller.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final status = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.busy) const LinearProgressIndicator(),
          if (_controller.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    '${_controller.error!} Дані можуть бути застарілими.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _controller.busy ? null : _controller.refresh,
                    child: const Text('Повторити'),
                  ),
                ],
              ),
            ),
        ],
      );
      if (!_controller.initialized) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('MealMate'),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await widget.auth.logout();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Вийти'),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  status,
                  if (_controller.busy)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Завантаження даних…'),
                    ),
                ],
              ),
            ),
          ),
        );
      }
      return MainShell(
        service: _controller.recipes,
        mealPlans: _controller.plans,
        shoppingList: _controller.shopping,
        nutritionSettings: _controller.settings,
        auth: widget.auth,
        statusBanner: _controller.busy || _controller.error != null
            ? status
            : null,
      );
    },
  );
}
