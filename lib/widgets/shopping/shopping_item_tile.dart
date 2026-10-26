import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_item.dart';

enum ShoppingItemAction { edit, delete }

class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    required this.item,
    required this.onPurchased,
    required this.onDelete,
    required this.onEdit,
    this.allowDelete = true,
    super.key,
  });
  final ShoppingItem item;
  final bool allowDelete;
  final ValueChanged<bool> onPurchased;
  final VoidCallback onDelete, onEdit;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: item.isPurchased ? AppColors.muted : AppColors.text,
      decoration: item.isPurchased ? TextDecoration.lineThrough : null,
    );
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              key: ValueKey('purchase-${item.id}'),
              value: item.isPurchased,
              onChanged: (value) => onPurchased(value ?? false),
              semanticLabel: 'Придбано: ${item.ingredientName}',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.ingredientName,
                    style: style.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(item.amountLabel, style: style.copyWith(fontSize: 12)),
                  if (item.isManual)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Додано вручну',
                        style: TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            if (item.isManual || allowDelete)
              PopupMenuButton<ShoppingItemAction>(
                tooltip: 'Дії: ${item.ingredientName}',
                onSelected: (action) =>
                    action == ShoppingItemAction.edit ? onEdit() : onDelete(),
                itemBuilder: (_) => [
                  if (item.isManual)
                    const PopupMenuItem(
                      value: ShoppingItemAction.edit,
                      child: Text('Змінити кількість'),
                    ),
                  if (allowDelete)
                    const PopupMenuItem(
                      value: ShoppingItemAction.delete,
                      child: Text('Видалити продукт'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
