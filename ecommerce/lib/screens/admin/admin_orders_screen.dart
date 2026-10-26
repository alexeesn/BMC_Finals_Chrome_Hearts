import 'package:flutter/material.dart';

import '../../models/admin.dart';
import '../../models/catalog.dart';
import '../../models/order.dart';
import '../../services/shop_gateway.dart';
import '../../widgets/shopping_feedback.dart';
import '../orders_screen.dart' show paymentStatusLabel;
import 'admin_guard.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key, required this.shop});
  final ShopGateway shop;
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  int _offset = 0;
  String? _status;
  late Future<List<ShopOrder>> _orders = widget.shop.admin.loadOrders(
    offset: _offset,
  );
  void _load() {
    _orders = widget.shop.admin.loadOrders(
      offset: _offset,
      paymentStatus: _status,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _orders;
    } catch (_) {
      /* FutureBuilder shows retry. */
    }
  }

  Future<void> _open(ShopOrder order) async {
    await openAdminPage<void>(
      context,
      widget.shop,
      (_) => AdminOrderScreen(shop: widget.shop, orderId: order.id),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          initialValue: 'all',
          decoration: const InputDecoration(labelText: 'Payment status'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All orders')),
            DropdownMenuItem(value: 'pending', child: Text('Pending payment')),
            DropdownMenuItem(value: 'paid', child: Text('Paid')),
            DropdownMenuItem(value: 'expired', child: Text('Expired')),
            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            DropdownMenuItem(
              value: 'needs_review',
              child: Text('Needs review'),
            ),
          ],
          onChanged: (value) => setState(() {
            _status = value == 'all' ? null : value;
            _offset = 0;
            _load();
          }),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<ShopOrder>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load store orders.'),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Retry store orders'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data!;
            final loading = snapshot.connectionState != ConnectionState.done;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  if (loading) const LinearProgressIndicator(),
                  if (orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching orders.'),
                    ),
                  ...orders.map(
                    (order) => Card(
                      child: ListTile(
                        onTap: loading ? null : () => _open(order),
                        title: Text(
                          order.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${paymentStatusLabel(order)} · ${order.fulfillmentStatus}\n${order.address.recipient}',
                        ),
                        isThreeLine: true,
                        trailing: Text(formatPesos(order.totalMinor)),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: loading || _offset == 0
                            ? null
                            : () => setState(() {
                                _offset -= 30;
                                _load();
                              }),
                        child: const Text('Previous'),
                      ),
                      Text('Page ${_offset ~/ 30 + 1}'),
                      TextButton(
                        onPressed: loading || orders.length < 30
                            ? null
                            : () => setState(() {
                                _offset += 30;
                                _load();
                              }),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({
    super.key,
    required this.shop,
    required this.orderId,
  });
  final ShopGateway shop;
  final String orderId;
  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  late Future<ShopOrder> _order = widget.shop.admin.loadOrder(widget.orderId);
  bool _saving = false;
  Future<void> _refresh() async {
    final future = widget.shop.admin.loadOrder(widget.orderId);
    setState(() => _order = future);
    try {
      await future;
    } catch (_) {
      /* FutureBuilder shows retry. */
    }
  }

  Future<void> _advance(String status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.shop.admin.updateFulfillment(widget.orderId, status);
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Manage order'),
      actions: [
        IconButton(
          tooltip: 'Refresh store order',
          onPressed: _saving ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<ShopOrder>(
      future: _order,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this store order.'),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry store order'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final order = snapshot.data!;
        final next = nextFulfillment(
          order.paymentStatus,
          order.fulfillmentStatus,
        );
        final loading =
            _saving || snapshot.connectionState != ConnectionState.done;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (loading) const LinearProgressIndicator(),
                Text(
                  order.number,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  paymentStatusLabel(order),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text('Fulfillment: ${order.fulfillmentStatus}'),
                const Divider(height: 32),
                Text('Delivery', style: Theme.of(context).textTheme.titleLarge),
                Text(order.address.recipient),
                Text(order.address.phone),
                Text(order.address.fullAddress),
                if (order.address.instructions.isNotEmpty)
                  Text(order.address.instructions),
                const Divider(height: 32),
                ...order.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.option} · ${item.quantity} × ${formatPesos(item.unitPriceMinor)}',
                    ),
                    trailing: Text(formatPesos(item.lineTotalMinor)),
                  ),
                ),
                const Divider(height: 24),
                _Amount('Subtotal', order.subtotalMinor),
                _Amount('Shipping', order.shippingMinor),
                _Amount('Total', order.totalMinor),
                const SizedBox(height: 24),
                if (next != null)
                  FilledButton.icon(
                    onPressed: loading ? null : () => _advance(next),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : next == 'shipped'
                          ? 'Mark as shipped'
                          : 'Mark as delivered',
                    ),
                  ),
                if (order.paymentStatus != 'paid')
                  const Text(
                    'Fulfillment becomes available after confirmed payment.',
                  ),
                if (order.fulfillmentStatus == 'delivered')
                  const Text('This order has been delivered.'),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.minor);
  final String label;
  final int minor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(formatPesos(minor)),
      ],
    ),
  );
}
