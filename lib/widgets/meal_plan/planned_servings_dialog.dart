import 'package:flutter/material.dart';

class PlannedServingsDialog extends StatefulWidget {
  const PlannedServingsDialog({required this.initialValue, super.key});
  final double initialValue;
  @override
  State<PlannedServingsDialog> createState() => _PlannedServingsDialogState();
}

class _PlannedServingsDialogState extends State<PlannedServingsDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toString().replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      double.parse(_controller.text.trim().replaceAll(',', '.')),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Заплановані порції',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Form(
            key: _form,
            child: TextFormField(
              key: const ValueKey('planned-servings-input'),
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Кількість порцій',
                helperText: 'Наприклад: 1 або 0,5',
                errorMaxLines: 3,
              ),
              validator: (text) {
                final n = double.tryParse(
                  (text ?? '').trim().replaceAll(',', '.'),
                );
                return n == null || !n.isFinite || n <= 0 || n > 1000
                    ? 'Введіть число більше 0 і до 1000'
                    : null;
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Скасувати'),
              ),
              TextButton(onPressed: _save, child: const Text('Зберегти')),
            ],
          ),
        ],
      ),
    ),
  );
}
