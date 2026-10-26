import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/auth_field.dart';
import '../../widgets/auth/auth_layout.dart';
import 'auth_validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({this.auth, super.key});
  final AuthService? auth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _busy = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.auth != null) {
        await widget.auth!.register(_name.text, _email.text, _password.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.auth == null
                  ? 'Форму заповнено правильно.'
                  : 'Обліковий запис створено. Увійдіть.',
            ),
          ),
        );
      if (widget.auth != null) {
        _password.clear();
        _confirmation.clear();
        _goToLogin();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      onBack: () {
        if (!_busy) _goToLogin();
      },
      eyebrow: 'Почнімо разом',
      title: 'Створити акаунт',
      subtitle: 'Зберігайте рецепти та плануйте меню на весь тиждень.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
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
                label: 'Ім’я',
                hint: 'Ваше ім’я',
                controller: _name,
                validator: AuthValidators.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),
              AuthField(
                label: 'Електронна пошта',
                hint: 'name@example.com',
                controller: _email,
                validator: AuthValidators.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              AuthField(
                label: 'Пароль',
                hint: 'Не менше 8 символів',
                controller: _password,
                validator: AuthValidators.newPassword,
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              AuthField(
                label: 'Підтвердіть пароль',
                hint: 'Повторіть пароль',
                controller: _confirmation,
                validator: (value) =>
                    AuthValidators.confirmPassword(value, _password.text),
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: 'Зареєструватися',
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
      footer: AuthFooter(
        prompt: 'Вже маєте акаунт?',
        action: 'Увійти',
        onPressed: _busy ? null : _goToLogin,
      ),
    );
  }
}
