import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/catalog.dart';
import '../models/checkout.dart';
import '../models/shopping.dart';
import '../models/order.dart';
import '../services/order_placement.dart';
import '../services/shop_gateway.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/shop_layout.dart';
import 'addresses_screen.dart';
import 'orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.gateway,
    required this.selection,
  });
  final ShopGateway gateway;
  final CheckoutSelection selection;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final _changes = widget.gateway.authChanges;
  late final _owner = widget.gateway.currentUser?.id;
  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: _changes,
    builder: (context, _) {
      if (_owner == null || widget.gateway.currentUser?.id != _owner) {
        return Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Account changed. Go back and select your items again.',
              ),
            ),
          ),
        );
      }
      return _CheckoutReview(
        gateway: widget.gateway,
        selection: widget.selection,
      );
    },
  );
}

class _CheckoutReview extends StatefulWidget {
  const _CheckoutReview({required this.gateway, required this.selection});
  final ShopGateway gateway;
  final CheckoutSelection selection;
  @override
  State<_CheckoutReview> createState() => _CheckoutReviewState();
}

class _CheckoutReviewState extends State<_CheckoutReview> {
  List<DeliveryAddress>? _addresses;
  String? _addressId;
  CheckoutQuote? _quote;
  bool _loading = true;
  String? _error;
  int _request = 0;
  bool _placing = false;
  CheckoutAttempt? _attempt;
  CheckoutAttempt? _unfinished;
  ShopOrder? _placedOrder;
  late final _owner = widget.gateway.currentUser?.id;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final previous = await widget.gateway.loadCheckoutAttempt();
      if (!mounted || widget.gateway.currentUser?.id != _owner) return;
      setState(() => _unfinished = previous);
      await _loadAddresses();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Unable to restore checkout. Check My orders before continuing.';
        });
      }
    }
  }

  Future<void> _place() async {
    if (_placing || _quote == null || _unfinished != null) return;
    _attempt ??= CheckoutAttempt(
      key: const Uuid().v4(),
      source: widget.selection.source,
      addressId: _addressId!,
      items: widget.selection.items,
    );
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final order = await placeOrResumeOrder(widget.gateway, _attempt!);
      if (mounted && widget.gateway.currentUser?.id == _owner) {
        setState(() => _placedOrder = order);
      }
    } on CheckoutRejected catch (error) {
      if (mounted) {
        setState(() => _attempt = null);
        await _loadAddresses();
        if (mounted) setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ShoppingException ? error.message : 'Unable to confirm checkout. Retry this same checkout or check My orders.',
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _viewOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrdersScreen(gateway: widget.gateway),
      ),
    );
    if (mounted && _attempt == null) await _initialize();
  }

  Future<void> _loadAddresses() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _quote = null;
      _error = null;
    });
    try {
      final addresses = await widget.gateway.loadAddresses();
      if (!mounted || request != _request) return;
      String? selected = _addressId;
      if (!addresses.any((address) => address.id == selected)) selected = null;
      selected ??= addresses
          .where((address) => address.isDefault)
          .firstOrNull
          ?.id;
      selected ??= addresses.firstOrNull?.id;
      setState(() {
        _addresses = addresses;
        _addressId = selected;
        _loading = false;
      });
      if (selected != null) await _loadQuote(selected);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = 'Unable to load delivery addresses. Please retry.';
        });
      }
    }
  }

  Future<void> _loadQuote(String addressId) async {
    final request = ++_request;
    setState(() {
      _addressId = addressId;
      _quote = null;
      _loading = true;
      _error = null;
    });
    try {
      final quote = await widget.gateway.quoteCheckout(
        widget.selection,
        addressId,
      );
      if (mounted && request == _request) setState(() => _quote = quote);
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is ShoppingException ? error.message : 'Unable to review this order. Refresh your selection and try again.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _manageAddresses() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddressesScreen(gateway: widget.gateway),
      ),
    );
    if (mounted) await _loadAddresses();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gateway.currentUser?.id != _owner) {
      return const Scaffold(
        body: Center(
          child: Text('Account changed. Return to checkout after signing in.'),
        ),
      );
    }
    if (_placedOrder != null) {
      return OrderDetailsScreen(
        gateway: widget.gateway,
        orderId: _placedOrder!.id,
        initialOrder: _placedOrder,
        previousTotalMinor: _quote?.totalMinor,
      );
    }
    final quote = _quote;
    final frozen = _attempt != null || _placing;
    final address = ShopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '01 / Delivery address',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_addresses != null && _addresses!.isEmpty)
            const Text('Add a delivery address to review your order.'),
          if (_addresses != null && _addresses!.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey(_addressId),
              initialValue: _addressId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Deliver to'),
              items: _addresses!
                  .map(
                    (address) => DropdownMenuItem(
                      value: address.id,
                      child: Text(
                        '${address.recipient} · ${address.city}${address.isDefault ? ' · Default' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _loading || frozen
                  ? null
                  : (id) {
                      if (id != null) _loadQuote(id);
                    },
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loading || frozen ? null : _manageAddresses,
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Add / edit addresses'),
          ),
          if (quote != null) ...[
            const Divider(height: 24),
            Text(
              quote.address.recipient,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(quote.address.phone),
            const SizedBox(height: 6),
            Text(quote.address.fullAddress),
            if (quote.address.instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(quote.address.instructions),
            ],
          ],
        ],
      ),
    );
    final items = quote == null
        ? null
        : ShopPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '02 / Your selection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                for (var index = 0; index < quote.items.length; index++) ...[
                  if (index > 0) const Divider(height: 28),
                  Text(
                    quote.items[index].name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${quote.items[index].option} · ${formatPesos(quote.items[index].unitPriceMinor)} × ${quote.items[index].quantity}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(formatPesos(quote.items[index].lineTotalMinor)),
                    ],
                  ),
                ],
              ],
            ),
          );
    final summary = quote == null
        ? null
        : ShopPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Order summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                _MoneyRow(label: 'Subtotal', value: quote.subtotalMinor),
                _MoneyRow(label: 'Shipping', value: quote.shippingMinor),
                const Divider(height: 28),
                _MoneyRow(label: 'Total', value: quote.totalMinor, total: true),
                const Divider(height: 28),
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Payment via Xendit')),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Prices and stock are checked again when you continue to payment.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
    return PopScope(
      canPop: !_placing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          actions: [
            IconButton(
              tooltip: 'Refresh checkout',
              onPressed: _loading || frozen ? null : _initialize,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ShopHeading(
                    eyebrow: 'Checkout / Review',
                    title: 'One last look.',
                    subtitle: 'Check your selection and delivery details before placing your order.',
                  ),
                  const SizedBox(height: 28),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null) ...[
                    ShopPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton(
                            onPressed: _loading || frozen ? null : _initialize,
                            child: const Text('Retry checkout'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_unfinished != null) ...[
                    ShopPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You have an unfinished checkout. Resume it from My orders first.',
                          ),
                          TextButton(
                            onPressed: _placing ? null : _viewOrders,
                            child: const Text('Open My orders'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_attempt != null && !_placing)
                    TextButton(
                      onPressed: _viewOrders,
                      child: const Text('Check My orders'),
                    ),
                  LayoutBuilder(
                    builder: (context, box) {
                      final selection = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          address,
                          if (items != null) ...[
                            const SizedBox(height: 20),
                            items,
                          ],
                        ],
                      );
                      if (box.maxWidth >= 800 && summary != null) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: selection),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: summary),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          selection,
                          if (summary != null) ...[
                            const SizedBox(height: 20),
                            summary,
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: quote == null
            ? null
            : ShopFooter(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading || _placing || _unfinished != null
                        ? null
                        : _place,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(
                      _placing
                          ? 'Placing order…'
                          : _attempt == null
                          ? 'Place Order'
                          : 'Retry same checkout',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.total = false,
  });
  final String label;
  final int value;
  final bool total;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(label),
        Text(
          formatPesos(value),
          style: total ? Theme.of(context).textTheme.titleLarge : null,
        ),
      ],
    ),
  );
}

Future<void> openCheckout(
  BuildContext context,
  ShopGateway gateway,
  CheckoutSelection selection,
) async {
  if (!await ensureSignedIn(context, gateway)) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CheckoutScreen(gateway: gateway, selection: selection),
    ),
  );
}
