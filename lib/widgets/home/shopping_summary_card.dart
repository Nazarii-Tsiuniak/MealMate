import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../services/shopping_list_service.dart';

class ShoppingSummaryCard extends StatelessWidget {
  const ShoppingSummaryCard({
    required this.shopping,
    required this.onShopping,
    super.key,
  });
  final ShoppingListService shopping;
  final VoidCallback onShopping;
  @override
  Widget build(BuildContext context) {
    final total = shopping.items.length;
    final purchased = shopping.purchased;
    final message = total == 0
        ? 'Ваш список покупок поки порожній'
        : purchased == total
        ? 'Усі покупки виконано!'
        : 'Придбано $purchased із $total продуктів';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDFE9D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Продукти для ваших страв',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      MealPlanDates.weekLabel(shopping.selectedWeek),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onShopping,
            child: const Text('Перейти до покупок'),
          ),
        ],
      ),
    );
  }
}
