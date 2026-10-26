import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PreparationStepTile extends StatelessWidget {
  const PreparationStepTile({
    required this.number,
    required this.text,
    super.key,
  });
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 36),
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: const TextStyle(height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }
}
