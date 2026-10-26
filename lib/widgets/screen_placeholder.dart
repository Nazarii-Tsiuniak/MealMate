import 'package:flutter/material.dart';

/// Тимчасовий вміст екранів першого етапу.
class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({required this.title, super.key, this.child});

  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Екран у підготовці', textAlign: TextAlign.center),
              if (child != null) ...[const SizedBox(height: 24), child!],
            ],
          ),
        ),
      ),
    );
  }
}
