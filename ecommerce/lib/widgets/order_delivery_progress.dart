import 'package:flutter/material.dart';

class OrderDeliveryProgress extends StatelessWidget {
  const OrderDeliveryProgress({super.key, required this.status});

  final String status;

  static const _stages = [
    (status: 'preparing', label: 'Preparing', icon: Icons.inventory_2_outlined),
    (status: 'shipped', label: 'Shipped', icon: Icons.local_shipping_outlined),
    (status: 'delivered', label: 'Delivered', icon: Icons.home_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _stages.indexWhere((stage) => stage.status == status);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery progress', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (current < 0)
              const Text('Refresh your order for the latest delivery status.')
            else
              for (var index = 0; index < _stages.length; index++) ...[
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 19),
                    child: SizedBox(
                      height: 16,
                      child: VerticalDivider(
                        width: 2,
                        color: index <= current
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                    ),
                  ),
                _stage(context, index, current),
              ],
          ],
        ),
      ),
    );
  }

  Widget _stage(BuildContext context, int index, int current) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reached = index <= current;
    final complete = index < current || current == _stages.length - 1;
    final note = complete
        ? 'Completed'
        : index == current
        ? 'Current stage'
        : 'Upcoming';
    final stage = _stages[index];

    return Semantics(
      label: '${stage.label}, $note',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached ? colors.primary : colors.surfaceContainerHighest,
            ),
            child: Icon(
              complete ? Icons.check : stage.icon,
              size: 20,
              color: reached ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: reached ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
                Text(note, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
