import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ShoppingProgressCard extends StatelessWidget {
  const ShoppingProgressCard({
    required this.purchased,
    required this.total,
    super.key,
  });
  final int purchased, total;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.lightGreen,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                total > 0 && purchased == total
                    ? 'Усі покупки виконано!'
                    : 'Придбано $purchased із $total',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Прогрес покупок',
          value: '$purchased із $total',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : purchased / total,
              minHeight: 6,
              backgroundColor: Colors.white,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
}
