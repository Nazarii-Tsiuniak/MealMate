import 'package:flutter/material.dart';
import '../../services/nutrition_settings_service.dart';
import '../../services/auth_service.dart';
import '../../core/utils/action_feedback.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.settings, this.auth, super.key});
  final NutritionSettingsService settings;
  final AuthService? auth;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _goal;
  @override
  void initState() {
    super.initState();
    _goal = TextEditingController(text: widget.settings.dailyGoal.toString());
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.settings.setDailyGoalAsync(int.parse(_goal.text.trim()));
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Денну ціль збережено')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Профіль')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.auth?.user != null) ...[
                Text(
                  widget.auth!.user!.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(widget.auth!.user!.email),
                const SizedBox(height: 20),
              ],
              if (_busy) const LinearProgressIndicator(),
              const Text(
                'Денна ціль калорій',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '2000 ккал — початковий демонстраційний приклад, а не індивідуальна рекомендація. Встановіть власну ціль.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('daily-calorie-goal'),
                controller: _goal,
                decoration: const InputDecoration(
                  labelText: 'Ціль, ккал на день',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed <= 0 || parsed > 100000
                      ? 'Введіть ціле число від 1 до 100000'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Зберегти ціль'),
              ),
              const SizedBox(height: 20),
              Text(
                widget.settings.isRemote
                    ? 'Ціль зберігається у вашому профілі на сервері.'
                    : 'Ціль зберігається до перезапуску застосунку.',
              ),
              if (widget.auth != null)
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => runAction(context, widget.auth!.logout),
                  icon: const Icon(Icons.logout),
                  label: const Text('Вийти з акаунта'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
