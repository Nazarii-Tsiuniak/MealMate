import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/offline_backup_service.dart';

class OfflineBackupActions extends StatefulWidget {
  const OfflineBackupActions({required this.service, super.key});
  final OfflineBackupService service;
  @override
  State<OfflineBackupActions> createState() => _OfflineBackupActionsState();
}

class _OfflineBackupActionsState extends State<OfflineBackupActions> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не вдалося обробити копію. Дані не очищено. Перевірте файл і спробуйте ще раз.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool previous = false}) async {
    final text = previous
        ? await widget.service.previousText()
        : await widget.service.exportText();
    if (text == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Попередньої копії поки немає')),
        );
      }
      return;
    }
    final uri = await FilePicker.saveFile(
      fileName: 'mealmate-backup.json',
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    if (uri != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Резервну копію збережено')));
    }
  }

  Future<void> _restore() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    final length = await file.length();
    if (length != null && length > 10 * 1024 * 1024) {
      throw const FormatException('Файл завеликий');
    }
    final text = utf8.decode(await file.readAsBytes());
    final data = widget.service.validate(text);
    if (!mounted) return;
    final replace = data['mode'] == 'backup';
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          replace ? 'Відновити резервну копію?' : 'Імпортувати дані?',
        ),
        content: Text(
          replace
              ? 'Поточні локальні дані буде замінено. Їхню копію буде збережено перед відновленням.'
              : 'Дані буде об’єднано за ID. Записи з однаковими ID буде оновлено. Попередню копію буде збережено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Продовжити'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await widget.service.importText(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Дані відновлено. Попередня копія доступна у профілі.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Резервні копії',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      if (_busy) const LinearProgressIndicator(),
      TextButton.icon(
        onPressed: _busy ? null : () => _run(_save),
        icon: const Icon(Icons.save_alt),
        label: const Text('Зберегти резервну копію'),
      ),
      TextButton.icon(
        onPressed: _busy ? null : () => _run(_restore),
        icon: const Icon(Icons.restore),
        label: const Text('Імпортувати / відновити'),
      ),
      TextButton(
        onPressed: _busy ? null : () => _run(() => _save(previous: true)),
        child: const Text('Зберегти попередню копію'),
      ),
    ],
  );
}
