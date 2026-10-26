import 'package:flutter/material.dart';
import '../../core/utils/action_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_item.dart';
import '../../services/shopping_list_service.dart';
import '../../widgets/shopping/shopping_item_tile.dart';
import '../../widgets/shopping/shopping_progress_card.dart';
import '../../widgets/shopping/shopping_week_selector.dart';
import 'shopping_item_form_screen.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({required this.service, super.key});
  final ShoppingListService service;
  void _form(BuildContext context, [ShoppingItem? item]) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ShoppingItemFormScreen(
            service: service,
            week: service.selectedWeek,
            item: item,
          ),
        ),
      );
  Future<void> _clear(BuildContext context) async {
    final week = service.selectedWeek;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          service.isRemote
              ? 'Видалити ручні продукти?'
              : 'Очистити список покупок?',
        ),
        content: Text(
          service.isRemote
              ? 'Ручні продукти буде видалено. Автоматичні продукти формуються з плану харчування.'
              : 'Усі проду за вибраний тиждень буде видалено. Автоматичні продукти з’являться знову після зміни плану або інгредієнтів.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистити'),
          ),
        ],
      ),
    );
    if (confirmed == true && week == service.selectedWeek && context.mounted) {
      await runAction(context, service.clearAsync);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final items = service.items;
      return CustomScrollView(
        key: PageStorageKey(
          'shopping-${service.selectedWeek.toIso8601String()}',
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Список покупок',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: service.isRemote
                            ? 'Очистити ручні продукти'
                            : 'Очистити список',
                        onPressed:
                            (service.isRemote
                                ? !items.any((item) => item.isManual)
                                : items.isEmpty)
                            ? null
                            : () => _clear(context),
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ShoppingWeekSelector(
                    week: service.selectedWeek,
                    onSelected: service.selectWeek,
                  ),
                  const SizedBox(height: 12),
                  ShoppingProgressCard(
                    purchased: service.purchased,
                    total: items.length,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('add-shopping'),
                      onPressed: () => _form(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Додати продукт'),
                    ),
                  ),
                  if (!service.hasPlan)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(
                        'Спочатку додайте страви до плану харчування',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Ваш список покупок поки порожній',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          for (final category in ShoppingCategory.values) ...[
            if (items.any((item) => item.category == category)) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${category.label} · ${items.where((item) => item.category == category).length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.list(
                  children: [
                    for (final item in items.where(
                      (item) => item.category == category,
                    ))
                      Column(
                        key: ValueKey('shopping-row-${item.id}'),
                        children: [
                          ShoppingItemTile(
                            item: item,
                            onPurchased: (value) => runAction(
                              context,
                              () => service.setPurchasedAsync(item.id, value),
                            ),
                            onDelete: () => runAction(
                              context,
                              () => service.removeAsync(item.id),
                            ),
                            allowDelete: !service.isRemote || item.isManual,
                            onEdit: () => _form(context, item),
                          ),
                          const Divider(height: 1, color: Color(0xFFE0E6E1)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      );
    },
  );
}
