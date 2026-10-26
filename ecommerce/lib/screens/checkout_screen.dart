import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/checkout.dart';
import '../models/shopping.dart';
import '../services/shop_gateway.dart';
import '../widgets/sign_in_prompt.dart';
import 'addresses_screen.dart';

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
  @override
  void initState() {
    super.initState();
    _loadAddresses();
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
    final quote = _quote;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: [
          IconButton(
            tooltip: 'Refresh checkout',
            onPressed: _loading ? null : _loadAddresses,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Delivery address',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
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
                  onChanged: _loading
                      ? null
                      : (id) {
                          if (id != null) _loadQuote(id);
                        },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _manageAddresses,
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Add / edit addresses'),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _loading ? null : _loadAddresses,
                  child: const Text('Retry checkout'),
                ),
              ],
              if (quote != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.address.recipient,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(quote.address.phone),
                        Text(quote.address.fullAddress),
                        if (quote.address.instructions.isNotEmpty)
                          Text(quote.address.instructions),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Order items',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ...quote.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.option} · ${formatPesos(item.unitPriceMinor)} × ${item.quantity}',
                    ),
                    trailing: Text(formatPesos(item.lineTotalMinor)),
                  ),
                ),
                const Divider(height: 32),
                _MoneyRow(label: 'Subtotal', value: quote.subtotalMinor),
                _MoneyRow(label: 'Shipping', value: quote.shippingMinor),
                const Divider(height: 24),
                _MoneyRow(label: 'Total', value: quote.totalMinor, total: true),
                const SizedBox(height: 20),
                const Text(
                  'Prices and stock are checked again when you continue to payment.',
                ),
              ],
            ],
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
    child: Row(
      children: [
        Expanded(child: Text(label)),
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
