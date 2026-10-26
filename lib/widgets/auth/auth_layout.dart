import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Спільне адаптивне компонування екранів авторизації.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 16),
    this.brandSpacing,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final double? brandSpacing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F5EE), AppColors.background],
            stops: [0, 0.42],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 440,
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 48,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: onBack == null ? 0 : 48,
                                    ),
                                    child: const Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: _Brand(),
                                      ),
                                    ),
                                  ),
                                  if (onBack != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: IconButton(
                                        onPressed: onBack,
                                        tooltip: 'Назад до входу',
                                        icon: const Icon(
                                          Icons.arrow_back_ios_new,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height:
                                  brandSpacing ?? (onBack == null ? 60 : 38),
                            ),
                            Text(
                              eyebrow.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 30,
                                height: 1.15,
                                letterSpacing: -1,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            form,
                            const SizedBox(height: 36),
                            const Spacer(),
                            footer,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x242D654E),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_outlined,
            size: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'MealMate',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class AuthFooter extends StatelessWidget {
  const AuthFooter({
    required this.prompt,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            action,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x262D654E),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
