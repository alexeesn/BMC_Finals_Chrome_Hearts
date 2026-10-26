import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../services/cart_controller.dart';
import '../widgets/product_art.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/shopping_feedback.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.cart});
  final CartController cart;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _selected = <String>{};
  final _known = <String>{};
  String? _owner;

  Future<void> _change(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    }
  }

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
      return Scaffold(
        appBar: AppBar(
          title: const Text('My cart'),
          actions: [
            IconButton(
              tooltip: 'Refresh cart',
              onPressed: editable ? cart.refresh : null,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: owner == null
            ? SignInPrompt(
                gateway: cart.gateway,
                message: 'Sign in to save and view your cart.',
              )
            : cart.loading && cart.lines.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : cart.error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cart.error!),
                    TextButton(
                      onPressed: cart.refresh,
                      child: const Text('Retry cart'),
                    ),
                  ],
                ),
              )
            : cart.lines.isEmpty
            ? const Center(
                child: Text('Your cart is empty. Explore the collection.'),
              )
            : Column(
                children: [
                  if (cart.loading || cart.busy)
                    const LinearProgressIndicator(),
                  CheckboxListTile(
                    title: const Text('Select all'),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selected.length == cart.lines.length,
                    onChanged: editable
                        ? (all) => setState(() {
                            _selected.clear();
                            if (all == true) _selected.addAll(ids);
                          })
                        : null,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cart.refresh,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: cart.lines.length,
                        itemBuilder: (context, index) {
                          final line = cart.lines[index];
                          final variant = line.variant;
                          final product = line.product;
                          final maxQty = variant == null
                              ? 0
                              : variant.availableStock.clamp(0, 99);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
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
                                      if (product != null)
                                        SizedBox(
                                          width: 64,
                                          height: 76,
                                          child: ProductArt(product: product),
                                        ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product?.name ??
                                                  'Unavailable product',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            if (variant != null)
                                              Text(variant.label),
                                            if (variant != null)
                                              Text(
                                                formatPesos(variant.priceMinor),
                                              ),
                                            if (!line.available)
                                              const Text(
                                                'Unavailable quantity. Update or remove this item.',
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      IconButton(
                                        tooltip: 'Decrease quantity',
                                        onPressed:
                                            editable &&
                                                line.quantity > 1 &&
                                                maxQty > 0
                                            ? () => _change(
                                                () => cart.update(
                                                  line,
                                                  (line.quantity - 1).clamp(
                                                    1,
                                                    maxQty,
                                                  ),
                                                ),
                                              )
                                            : null,
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      Text(
                                        '${line.quantity}',
                                        semanticsLabel:
                                            'Quantity ${line.quantity}',
                                      ),
                                      IconButton(
                                        tooltip: 'Increase quantity',
                                        onPressed:
                                            editable && line.quantity < maxQty
                                            ? () => _change(
                                                () => cart.update(
                                                  line,
                                                  line.quantity + 1,
                                                ),
                                              )
                                            : null,
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: editable
                                            ? () => _change(
                                                () => cart.remove(line),
                                              )
                                            : null,
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Selected subtotal (${selected.length})',
                            ),
                          ),
                          Text(
                            formatPesos(subtotal),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}
