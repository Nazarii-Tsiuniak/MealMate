import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class WeeklyPlanCard extends StatelessWidget {
  const WeeklyPlanCard({required this.planned, required this.total, super.key});
  final int planned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (planned / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF376C55), AppColors.primary],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x182D654E),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ПЛАН НА ТИЖДЕНЬ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$planned із $total страв',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  planned == 0
                      ? 'Почніть планувати свій тиждень'
                      : planned == total
                      ? 'Усе заплановано'
                      : 'Плануйте смачний тиждень',
                  style: TextStyle(color: Color(0xFFE8F1EB), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Заплановано',
            value: '${(progress * 100).round()} відсотків',
            child: SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFF72927D),
                      color: const Color(0xFFD6EF91),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
