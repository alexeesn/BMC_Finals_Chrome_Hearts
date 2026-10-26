import 'package:flutter/material.dart';

import '../services/cart_controller.dart';

class ShopHeaderButton extends StatelessWidget {
  const ShopHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      minimumSize: const Size(44, 44),
      shape: const CircleBorder(),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

class ShopCartButton extends StatelessWidget {
  const ShopCartButton({
    super.key,
    required this.cart,
    required this.onPressed,
  });

  final CartController cart;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: cart,
    builder: (context, _) => Semantics(
      label: '${cart.count} items in cart',
      child: Badge(
        isLabelVisible: cart.count > 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        textColor: Theme.of(context).colorScheme.onPrimary,
        label: Text('${cart.count}', style: const TextStyle(fontSize: 10)),
        child: ShopHeaderButton(
          icon: Icons.shopping_bag_outlined,
          tooltip: 'Open cart',
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

class ShopBottomNavigation extends StatelessWidget {
  const ShopBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _destinations = [
    (label: 'Home', icon: Icons.home_outlined),
    (label: 'Categories', icon: Icons.grid_view_outlined),
    (label: 'Cart', icon: Icons.shopping_bag_outlined),
    (label: 'Account', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff101012),
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_destinations.length, (index) {
                final selected = selectedIndex == index;
                final color = selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant;
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    child: InkWell(
                      onTap: () => onSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _destinations[index].icon,
                              size: 20,
                              color: color,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _destinations[index].label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    ),
  );
}
