import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/checkout.dart';
import '../models/shopping.dart';
import 'checkout_screen.dart';
import '../services/cart_controller.dart';
import '../widgets/product_art.dart';
import '../widgets/shop_layout.dart';
import '../widgets/shop_navigation.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/shopping_feedback.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.cart, this.onViewCollection});
  final CartController cart;
  final VoidCallback? onViewCollection;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _selected = <String>{};
  final _known = <String>{};
  String? _owner;

  Future<void> _checkout(CheckoutSelection selection) async {
    await openCheckout(context, widget.cart.gateway, selection);
    await widget.cart.refresh();
  }

  Future<void> _change(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    }
  }

  Widget _quantity(CartLine line, bool editable) {
    final maxQty = line.variant?.availableStock.clamp(0, 99) ?? 0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Decrease quantity',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 16,
                onPressed: editable && line.quantity > 1 && maxQty > 0
                    ? () => _change(
                        () => widget.cart.update(
                          line,
                          (line.quantity - 1).clamp(1, maxQty),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                '${line.quantity}',
                semanticsLabel: 'Quantity ${line.quantity}',
              ),
              IconButton(
                tooltip: 'Increase quantity',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 16,
                onPressed: editable && line.quantity < maxQty
                    ? () => _change(
                        () => widget.cart.update(line, line.quantity + 1),
                      )
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: editable
              ? () => _change(() => widget.cart.remove(line))
              : null,
          child: const Text('Remove', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _item(CartLine line, bool editable) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          height: 84,
          child: Checkbox(
            value: _selected.contains(line.id),
            onChanged: editable
                ? (value) => setState(() {
                    if (value == true) {
                      _selected.add(line.id);
                    } else {
                      _selected.remove(line.id);
                    }
                  })
                : null,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          height: 84,
          child: line.product == null
              ? const Icon(Icons.image_outlined)
              : ProductArt(product: line.product!),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.product?.name ?? 'Unavailable product',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (line.variant != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Size: ${line.variant!.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPesos(line.variant!.priceMinor),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (!line.available)
                const Text('Unavailable quantity. Update or remove this item.'),
              const SizedBox(height: 12),
              _quantity(line, editable),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.cart,
    builder: (context, _) {
      final cart = widget.cart;
      final owner = cart.gateway.currentUser?.id;
      if (_owner != owner) {
        _owner = owner;
        _selected.clear();
        _known.clear();
      }
      final ids = cart.lines.map((line) => line.id).toSet();
      _selected.removeWhere((id) => !ids.contains(id));
      _selected.addAll(ids.difference(_known));
      _known
        ..clear()
        ..addAll(ids);
      final selected = cart.lines.where((line) => _selected.contains(line.id));
      final subtotal = selected.fold(
        0,
        (total, line) => total + (line.subtotal ?? 0),
      );
      final editable = !cart.busy && !cart.loading;
      final checkout = FilledButton(
        onPressed:
            editable &&
                selected.isNotEmpty &&
                selected.length <= 20 &&
                selected.every((line) => line.available)
            ? () => _checkout(
                CheckoutSelection.cart(selected.map((line) => line.id)),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Checkout'),
            Text(' (${selected.fold(0, (sum, line) => sum + line.quantity)})'),
          ],
        ),
      );
      final total = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected subtotal (${selected.length})',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatPesos(subtotal),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      );
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          leadingWidth: widget.onViewCollection == null ? null : 64,
          leading: widget.onViewCollection == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Center(
                    child: ShopHeaderButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Continue shopping',
                      onPressed: widget.onViewCollection,
                    ),
                  ),
                ),
          title: const Text('Your cart'),
          actions: [
            Center(
              child: Text(
                '${cart.lines.length} items',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: owner == null
                ? SignInPrompt(
                    gateway: cart.gateway,
                    message: 'Sign in to save and view your cart.',
                  )
                : cart.loading && cart.lines.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : cart.error != null
                ? ShopEmptyState(
                    icon: Icons.wifi_off_outlined,
                    title: 'Your bag is taking a moment.',
                    message: cart.error!,
                    action: TextButton(
                      onPressed: cart.refresh,
                      child: const Text('Retry cart'),
                    ),
                  )
                : cart.lines.isEmpty
                ? ShopEmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Your next piece awaits.',
                    message: 'Your cart is empty. Explore the collection.',
                    action: widget.onViewCollection == null
                        ? null
                        : OutlinedButton(
                            onPressed: widget.onViewCollection,
                            child: const Text('Continue shopping'),
                          ),
                  )
                : Column(
                    children: [
                      if (cart.loading || cart.busy)
                        const LinearProgressIndicator(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Select all items',
                            style: TextStyle(fontSize: 12),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.length == cart.lines.length,
                          onChanged: editable
                              ? (all) => setState(() {
                                  _selected.clear();
                                  if (all == true) _selected.addAll(ids);
                                })
                              : null,
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: cart.refresh,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            itemCount: cart.lines.length + 1,
                            itemBuilder: (context, index) {
                              if (index < cart.lines.length) {
                                return _item(cart.lines[index], editable);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: ShopPanel(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Choose the pieces you want to order. Shipping is added at checkout.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        bottomNavigationBar:
            owner == null || cart.lines.isEmpty || cart.error != null
            ? null
            : ShopFooter(
                maxWidth: 860,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final stacked =
                        box.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (stacked) ...[
                          total,
                          const SizedBox(height: 12),
                          checkout,
                        ] else
                          Row(
                            children: [
                              Expanded(child: total),
                              const SizedBox(width: 10),
                              Expanded(child: checkout),
                            ],
                          ),
                        if (selected.length > 20)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Select up to 20 different items per checkout.',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
      );
    },
  );
}
