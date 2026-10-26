import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalog.dart';
import '../models/order.dart';
import '../services/order_placement.dart';
import '../services/shop_gateway.dart';
import '../widgets/order_delivery_progress.dart';
import '../widgets/shopping_feedback.dart';
import '../widgets/sign_in_prompt.dart';

String paymentStatusLabel(ShopOrder order) => switch (order.paymentStatus) {
  'paid' => order.paid ? 'Paid' : 'Confirming payment',
  'expired' => 'Expired',
  'cancelled' => 'Cancelled',
  'needs_review' => 'Needs review',
  _ => 'Pending payment',
};

String _deliveryLabel(String status) => switch (status) {
  'preparing' => 'Preparing',
  'shipped' => 'Shipped',
  'delivered' => 'Delivered',
  _ => 'Updating delivery',
};

String _localOrderTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatMediumDate(local)} · '
      '${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.gateway});
  final ShopGateway gateway;
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final _changes = widget.gateway.authChanges;
  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: _changes,
    builder: (context, _) {
      final owner = widget.gateway.currentUser?.id;
      if (owner == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('My orders')),
          body: SignInPrompt(
            gateway: widget.gateway,
            message: 'Sign in to view your orders.',
          ),
        );
      }
      return _OrdersList(
        key: ValueKey(owner),
        gateway: widget.gateway,
        owner: owner,
      );
    },
  );
}

typedef _OrdersData = ({
  List<ShopOrder> orders,
  CheckoutAttempt? attempt,
  String? recoveryError,
});

class _OrdersList extends StatefulWidget {
  const _OrdersList({super.key, required this.gateway, required this.owner});
  final ShopGateway gateway;
  final String owner;
  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  late Future<_OrdersData> _data = _load();
  bool _resuming = false;
  Future<_OrdersData> _load() async {
    final orders = await widget.gateway.loadOrders();
    try {
      return (
        orders: orders,
        attempt: await widget.gateway.loadCheckoutAttempt(),
        recoveryError: null,
      );
    } catch (_) {
      return (
        orders: orders,
        attempt: null,
        recoveryError: 'Unable to restore an unfinished checkout. Check your saved orders below.',
      );
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {
      /* FutureBuilder displays retry. */
    }
  }

  Future<void> _open(ShopOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsScreen(
          gateway: widget.gateway,
          orderId: order.id,
          initialOrder: order,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _resume(CheckoutAttempt attempt) async {
    if (_resuming) return;
    setState(() => _resuming = true);
    try {
      final order = await placeOrResumeOrder(widget.gateway, attempt);
      if (mounted) await _open(order);
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) {
        setState(() => _resuming = false);
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My orders'),
      actions: [
        IconButton(
          tooltip: 'Refresh orders',
          onPressed: _resuming ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<_OrdersData>(
      future: _data,
      builder: (context, snapshot) {
        if (widget.gateway.currentUser?.id != widget.owner) {
          return const Center(
            child: Text('Account changed. Return to My orders.'),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load your orders.'),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry orders'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (data.recoveryError != null) Text(data.recoveryError!),
              if (data.attempt != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unfinished checkout',
                          style: TextStyle(fontSize: 20),
                        ),
                        const Text(
                          'Resume the same checkout to check its result.',
                        ),
                        FilledButton(
                          onPressed: _resuming
                              ? null
                              : () => _resume(data.attempt!),
                          child: Text(
                            _resuming ? 'Checking…' : 'Resume checkout',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (data.orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No orders yet.'),
                ),
              if (data.orders.length == 50)
                const Text('Showing your latest 50 orders.'),
              ...data.orders.map(
                (order) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _resuming ? null : () => _open(order),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.number,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                formatPesos(order.totalMinor),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${paymentStatusLabel(order)}'
                                '${order.paid ? ' · ${_deliveryLabel(order.fulfillmentStatus)}' : ''}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _localOrderTime(context, order.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.gateway,
    required this.orderId,
    this.initialOrder,
    this.launchPayment,
    this.previousTotalMinor,
  });
  final ShopGateway gateway;
  final String orderId;
  final ShopOrder? initialOrder;
  final Future<bool> Function(Uri uri)? launchPayment;
  final int? previousTotalMinor;
  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with WidgetsBindingObserver {
  late final _changes = widget.gateway.authChanges;
  late final _owner =
      widget.initialOrder?.ownerId ?? widget.gateway.currentUser?.id;
  ShopOrder? _order;
  String? _error;
  bool _loading = false;
  bool _opening = false;
  bool _foreground = true;
  bool _paymentOpened = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_foreground && _order?.pending == true) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_loading ||
        widget.gateway.currentUser?.id != _owner ||
        _owner == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.gateway.loadOrder(widget.orderId);
      if (mounted && widget.gateway.currentUser?.id == _owner) {
        setState(() => _order = order);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to refresh this order. Check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPayment(Uri uri) async {
    if (_opening) return;
    // Launch directly from this tap; browser pop-up checks require a user gesture.
    setState(() => _opening = true);
    try {
      final opened =
          await (widget.launchPayment?.call(uri) ??
              launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (!opened) throw StateError('Payment page not opened');
      if (mounted) setState(() => _paymentOpened = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the payment page. Allow pop-ups, then try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: _changes,
    builder: (context, _) {
      if (_owner == null || widget.gateway.currentUser?.id != _owner) {
        return Scaffold(
          appBar: AppBar(title: const Text('Order')),
          body: const Center(
            child: Text('Account changed. Return to My orders.'),
          ),
        );
      }
      final order = _order;
      final uri = trustedTestPaymentUri(order?.paymentUrl);
      final canPay =
          !_loading &&
          !_opening &&
          _error == null &&
          order?.canPay == true &&
          uri != null;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order details'),
          actions: [
            IconButton(
              tooltip: 'Refresh order status',
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: order == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Retry order'),
                          ),
                        ],
                      ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_loading) const LinearProgressIndicator(),
                      Text(
                        order.number,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        paymentStatusLabel(order),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (order.pending &&
                          widget.previousTotalMinor != null &&
                          widget.previousTotalMinor != order.totalMinor)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Order total changed from ${formatPesos(widget.previousTotalMinor!)}. '
                            'Review the updated items and total before continuing.',
                          ),
                        ),
                      if (order.paid)
                        OrderDeliveryProgress(status: order.fulfillmentStatus),
                      if (order.pending)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Your order is waiting for confirmed payment.\n'
                            'Payment deadline (local time): '
                            '${_localOrderTime(context, order.expiresAt)}',
                          ),
                        ),
                      if (order.paymentStatus == 'needs_review')
                        const Text(
                          'This payment needs a shop review. Please keep your order number.',
                        ),
                      if (order.pending &&
                          !order.expiresAt.isAfter(DateTime.now()))
                        const Text(
                          'Payment window ended. Waiting for confirmation of the final status.',
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const Divider(height: 32),
                      Text(
                        order.address.recipient,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                      _TotalRow('Subtotal', order.subtotalMinor),
                      _TotalRow('Shipping', order.shippingMinor),
                      _TotalRow('Total', order.totalMinor),
                      const SizedBox(height: 24),
                      if (order.pending && order.paymentState == 'reserved')
                        const Text(
                          'Payment preparation is incomplete. Resume this checkout from My orders.',
                        ),
                      if (order.pending &&
                          {'creating', 'unknown'}.contains(order.paymentState))
                        const Text(
                          'We are checking the payment setup. Refresh this order before trying another checkout.',
                        ),
                      if (canPay)
                        FilledButton.icon(
                          onPressed: () => _openPayment(uri),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Continue to Xendit'),
                        ),
                      if (order.pending &&
                          uri == null &&
                          order.paymentState == 'active')
                        const Text(
                          'Payment link unavailable. Please contact the shop with your order number.',
                        ),
                      if (_paymentOpened)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            'Return here after payment, then refresh the order status.',
                          ),
                        ),
                      if (order.pending)
                        TextButton(
                          onPressed: _loading ? null : _refresh,
                          child: const Text('Refresh payment status'),
                        ),
                      const SizedBox(height: 12),
                      const Text('School demo · Xendit Test Mode'),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(formatPesos(value)),
      ],
    ),
  );
}
