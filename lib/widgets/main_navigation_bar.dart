import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Головна',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: 'Рецепти',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'План',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          label: 'Покупки',
        ),
      ],
    );
  }
}
