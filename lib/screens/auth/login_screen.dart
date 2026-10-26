import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/auth_field.dart';
import '../../widgets/auth/auth_layout.dart';
import 'auth_validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({this.auth, super.key});
  final AuthService? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (widget.auth == null) {
      // Лише явно обраний локальний demo/UI-тест, без реальної сесії.
      _password.clear();
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth!.login(_email.text, _password.text);
      if (mounted) _password.clear();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Відновлення пароля'),
        content: const Text(
          'На цьому етапі відновлення пароля ще не реалізовано.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Зрозуміло'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      eyebrow: 'З поверненням',
      title: 'Вхід',
      subtitle: 'Увійдіть, щоб продовжити планувати смачні страви.',
      padding: const EdgeInsets.fromLTRB(30, 40, 30, 16),
      brandSpacing: 68,
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null || widget.auth?.notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error ?? widget.auth!.notice!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              AuthField(
                label: 'Електронна пошта',
                hint: 'name@example.com',
                controller: _email,
                validator: AuthValidators.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 20),
              AuthField(
                label: 'Пароль',
                hint: 'Введіть пароль',
                controller: _password,
                validator: AuthValidators.loginPassword,
                isPassword: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text(
                    'Забули пароль?',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AuthSubmitButton(
                label: 'Увійти',
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
      footer: AuthFooter(
        prompt: 'Ще немає акаунта?',
        action: 'Зареєструватися',
        onPressed: _busy
            ? null
            : () => Navigator.pushNamed(context, AppRoutes.register),
      ),
    );
  }
}
