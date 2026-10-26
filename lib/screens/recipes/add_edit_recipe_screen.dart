import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../models/recipe_ingredient.dart';
import '../../services/recipe_service.dart';
import '../../services/recipe_validation.dart';
import '../../widgets/recipes/ingredient_editor.dart';
import '../../widgets/recipes/recipe_form_draft.dart';
import '../../widgets/recipes/step_editor.dart';

class AddEditRecipeScreen extends StatefulWidget {
  const AddEditRecipeScreen({required this.service, this.recipeId, super.key});
  final RecipeService service;
  final String? recipeId;

  @override
  State<AddEditRecipeScreen> createState() => _AddEditRecipeScreenState();
}

class _AddEditRecipeScreenState extends State<AddEditRecipeScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _description,
      _time,
      _calories,
      _servings;
  final List<IngredientDraft> _ingredients = [];
  final List<StepDraft> _steps = [];
  RecipeCategory? _category;
  bool _saving = false;
  bool _missing = false;
  bool get _editing => widget.recipeId != null;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipeId == null
        ? null
        : widget.service.findById(widget.recipeId!);
    _missing = _editing && recipe == null;
    _name = TextEditingController(text: recipe?.name ?? '');
    _description = TextEditingController(text: recipe?.description ?? '');
    _time = TextEditingController(
      text: recipe?.preparationMinutes.toString() ?? '',
    );
    _calories = TextEditingController(text: recipe?.calories?.toString() ?? '');
    _servings = TextEditingController(text: recipe?.servings?.toString() ?? '');
    _category = recipe?.category;
    _ingredients.addAll(
      recipe == null
          ? [IngredientDraft()]
          : recipe.ingredients.map(IngredientDraft.new),
    );
    _steps.addAll(
      recipe == null
          ? [StepDraft()]
          : recipe.preparationSteps.map(StepDraft.new),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _time,
      _calories,
      _servings,
    ]) {
      controller.dispose();
    }
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  void _removeIngredient(IngredientDraft draft) {
    setState(() => _ingredients.remove(draft));
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

  void _removeStep(StepDraft draft) {
    setState(() => _steps.remove(draft));
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

  Future<void> _save() async {
    if (_saving) return;
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && invalid.first.mounted) {
          Scrollable.ensureVisible(
            invalid.first.context,
            duration: const Duration(milliseconds: 250),
            alignment: 0.1,
          );
        }
      });
      return;
    }
    setState(() => _saving = true);
    final recipe = Recipe(
      id: widget.recipeId ?? '',
      name: _name.text.trim(),
      description: _description.text.trim(),
      category: _category!,
      preparationMinutes: RecipeValidation.integer(_time.text)!,
      calories: _calories.text.trim().isEmpty
          ? null
          : RecipeValidation.integer(_calories.text),
      servings: RecipeValidation.integer(_servings.text)!,
      ingredients: _ingredients
          .map(
            (draft) => RecipeIngredient(
              name: draft.name.text.trim(),
              quantity: draft.toTaste
                  ? null
                  : RecipeValidation.decimal(draft.quantity.text),
              unit: draft.toTaste ? null : draft.unit,
              note: draft.toTaste ? 'за смаком' : null,
            ),
          )
          .toList(),
      preparationSteps: _steps
          .map((step) => step.controller.text.trim())
          .toList(),
    );
    try {
      final saved = await widget.service.saveAsync(recipe);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.pop(context, saved.id);
    } on ArgumentError catch (error) {
      _saveError(error.message.toString());
    } on StateError catch (error) {
      _saveError(error.message);
    } catch (e) {
      if (mounted) _saveError(e.toString());
    }
  }

  void _saveError(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller,
    String? Function(String?)? validator, {
    bool number = false,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: validator,
        keyboardType: number ? TextInputType.number : TextInputType.multiline,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? null : 1,
      ),
    );
  }

  Widget _sectionError(bool empty, String text) => FormField<bool>(
    validator: (_) => empty ? text : null,
    builder: (field) => field.errorText == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Редагувати рецепт' : 'Новий рецепт'),
      ),
      body: _missing
          ? const Center(child: Text('Рецепт не знайдено'))
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(20),
                // Усі поля входять у Form, навіть коли нижні рядки поза екраном.
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_saving) const LinearProgressIndicator(),
                      _field(
                        'recipe-name',
                        'Назва рецепта',
                        _name,
                        RecipeValidation.requiredText,
                      ),
                      _field(
                        'recipe-description',
                        'Опис рецепта',
                        _description,
                        null,
                        multiline: true,
                      ),
                      DropdownButtonFormField<RecipeCategory>(
                        key: const ValueKey('recipe-category'),
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Категорія',
                        ),
                        items: [
                          for (final category in RecipeCategory.values)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            ),
                        ],
                        onChanged: (value) => setState(() => _category = value),
                        validator: (value) =>
                            value == null ? 'Оберіть категорію' : null,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'recipe-time',
                        'Час приготування, хв',
                        _time,
                        RecipeValidation.positiveInteger,
                        number: true,
                      ),
                      _field(
                        'recipe-calories',
                        'Ккал на порцію (необов’язково)',
                        _calories,
                        RecipeValidation.calories,
                        number: true,
                      ),
                      _field(
                        'recipe-servings',
                        'Кількість порцій',
                        _servings,
                        RecipeValidation.positiveInteger,
                        number: true,
                      ),
                      const Text(
                        'Інгредієнти',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionError(
                        _ingredients.isEmpty,
                        'Додайте хоча б один інгредієнт',
                      ),
                      for (var index = 0; index < _ingredients.length; index++)
                        Padding(
                          key: ObjectKey(_ingredients[index]),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: IngredientEditor(
                            draft: _ingredients[index],
                            index: index,
                            onChanged: () => setState(() {}),
                            onRemove: () =>
                                _removeIngredient(_ingredients[index]),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _ingredients.add(IngredientDraft())),
                        icon: const Icon(Icons.add),
                        label: const Text('Додати інгредієнт'),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Приготування',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionError(_steps.isEmpty, 'Додайте хоча б один крок'),
                      for (var index = 0; index < _steps.length; index++)
                        Padding(
                          key: ObjectKey(_steps[index]),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: StepEditor(
                            draft: _steps[index],
                            index: index,
                            onRemove: () => _removeStep(_steps[index]),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _steps.add(StepDraft())),
                        icon: const Icon(Icons.add),
                        label: const Text('Додати крок'),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _missing
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_editing ? 'Зберегти зміни' : 'Зберегти рецепт'),
                ),
              ),
            ),
    );
  }
}
