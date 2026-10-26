import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/demo/recipe_demo_data.dart';
import '../../models/recipe.dart';
import 'recipe_api_client.dart';
import 'recipe_json.dart';

/// Окрема лабораторна демонстрація. Дані не потрапляють в основний каталог.
class RestDemoScreen extends StatefulWidget {
  const RestDemoScreen({required this.client, super.key});
  final RecipeApiClient client;
  @override
  State<RestDemoScreen> createState() => _RestDemoScreenState();
}

class _RestDemoScreenState extends State<RestDemoScreen> {
  final _editor = TextEditingController();
  List<Recipe> _recipes = [];
  final List<String> _history = [];
  String? _selectedId, _error;
  bool _busy = false;
  static const _json = JsonEncoder.withIndent('  ');
  @override
  void initState() {
    super.initState();
    _sample();
    _get();
  }

  @override
  void dispose() {
    _editor.dispose();
    // Клієнтом володіє окрема точка входу, тести можуть передати mock.
    super.dispose();
  }

  void _sample() {
    _selectedId = null;
    final data = RecipeJson.encode(
      RecipeDemoData.recipes.first,
      includeId: false,
    );
    data['name'] = 'Демонстраційний омлет';
    _editor.text = _json.convert(data);
  }

  Recipe _draft() => RecipeJson.decode(
    jsonDecode(_editor.text),
    idOverride: _selectedId ?? '',
  );
  Future<void> _run(String method, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on RecipeApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _record(
          '$method → ${error.statusCode ?? 'мережа / JSON'}: ${error.message}',
        );
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = 'Перевірте JSON: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _record(String entry) {
    _history.insert(0, entry);
    if (_history.length > 12) _history.removeLast();
  }

  void _success(String message, String method, int status) {
    _record('$method → HTTP $status. $message');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _get() => _run('GET', () async {
    final response = await widget.client.getRecipes();
    if (!mounted) return;
    setState(() {
      _recipes = response.data;
      if (_selectedId != null && !_recipes.any((r) => r.id == _selectedId)) {
        _sample();
      }
      _success(
        'Отримано рецептів: ${_recipes.length}',
        'GET /recipes',
        response.statusCode,
      );
    });
  });
  Future<void> _save(bool update) => _run(update ? 'PUT' : 'POST', () async {
    final draft = _draft();
    final response = update
        ? await widget.client.updateRecipe(draft)
        : await widget.client.createRecipe(draft);
    if (!mounted) return;
    setState(() {
      _recipes = [
        ..._recipes.where((r) => r.id != response.data.id),
        response.data,
      ];
      _selectedId = response.data.id;
      _editor.text = _json.convert(
        RecipeJson.encode(response.data, includeId: false),
      );
      _success(
        update ? 'Зміни збережено на сервері' : 'Рецепт створено на сервері',
        update ? 'PUT /recipes/$_selectedId' : 'POST /recipes',
        response.statusCode,
      );
    });
  });
  Future<void> _delete() async {
    final id = _selectedId;
    if (_busy || id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Видалити рецепт з API?'),
        content: const Text(
          'Цю дію неможливо скасувати. Основний каталог MealMate не зміниться.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run('DELETE', () async {
      final response = await widget.client.deleteRecipe(id);
      if (!mounted) return;
      setState(() {
        _recipes = _recipes.where((r) => r.id != id).toList();
        _sample();
        _success(
          'Рецепт видалено з сервера',
          'DELETE /recipes/$id',
          response.statusCode,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('REST API · демонстрація')),
    body: SafeArea(
      top: false,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Лабораторна робота №6–7',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText('API: ${widget.client.baseUrl}'),
          const Text(
            'Окремі серверні дані. План харчування та покупки не змінюються.',
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Column(
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 8),
                Text('Виконується HTTP-запит…'),
              ],
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                key: const ValueKey('api-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _get,
                child: const Text('GET · Отримати'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _save(false),
                child: const Text('POST · Створити'),
              ),
              OutlinedButton(
                onPressed: _busy || _selectedId == null
                    ? null
                    : () => _save(true),
                child: const Text('PUT · Зберегти'),
              ),
              OutlinedButton(
                onPressed: _busy || _selectedId == null ? null : _delete,
                child: const Text('DELETE · Видалити'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedId == null
                ? 'Новий рецепт · JSON запиту'
                : 'Вибрано ID: $_selectedId',
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(_sample),
            child: const Text('Новий зразок JSON'),
          ),
          TextField(
            key: const ValueKey('api-json'),
            controller: _editor,
            enabled: !_busy,
            minLines: 8,
            maxLines: 16,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Тіло POST / PUT (JSON)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Рецепти API · ${_recipes.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text('Оберіть рецепт, щоб завантажити його JSON у редактор.'),
          if (!_busy && _recipes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Серверний список порожній або ще не завантажений.'),
            ),
          for (final recipe in _recipes)
            Card(
              child: ListTile(
                selected: _selectedId == recipe.id,
                title: Text(recipe.name),
                subtitle: Text(
                  '${recipe.id} · ${recipe.category.label} · ${recipe.preparationMinutes} хв',
                ),
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _selectedId = recipe.id;
                        _editor.text = _json.convert(
                          RecipeJson.encode(recipe, includeId: false),
                        );
                      }),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Журнал запитів',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final entry in _history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SelectableText(entry),
            ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
