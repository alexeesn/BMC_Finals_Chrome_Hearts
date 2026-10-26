import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/checkout.dart';
import 'checkout_screen.dart';
import '../services/cart_controller.dart';
import '../widgets/product_art.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/shopping_feedback.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({
    super.key,
    required this.product,
    required this.cart,
    required this.onViewCart,
  });
  final CatalogProduct product;
  final CartController cart;
  final VoidCallback onViewCart;
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  CatalogVariant? _selected;
  int _quantity = 1;
  bool _saving = false;
  bool _buying = false;

  Future<void> _buyNow() async {
    if (_selected == null || _saving || _buying) return;
    final selection = CheckoutSelection.buyNow(_selected!.id, _quantity);
    setState(() => _buying = true);
    try {
      await openCheckout(context, widget.cart.gateway, selection);
    } finally {
      if (mounted) setState(() => _buying = false);
      await widget.cart.refresh();
    }
  }

  Future<void> _add() async {
    if (_saving || _selected == null) return;
    setState(() => _saving = true);
    try {
      if (!await ensureSignedIn(context, widget.cart.gateway)) return;
      if (!mounted) return;
      await widget.cart.add(_selected!.id, _quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () {
              if (!mounted) return;
              widget.onViewCart();
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final price = _selected?.priceMinor ?? product.startingPrice;
    return Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ProductArt(product: product),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                product.category.toUpperCase(),
                style: const TextStyle(letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: const TextStyle(fontFamily: 'serif', fontSize: 34),
              ),
              const SizedBox(height: 8),
              Text(
                price == null ? 'Unavailable' : formatPesos(price),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              const Text('OPTIONS'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: product.variants
                    .map(
                      (variant) => ChoiceChip(
                        label: Text(
                          '${variant.label}${variant.availableStock == 0 ? ' · Sold out' : ''}',
                        ),
                        selected: _selected?.id == variant.id,
                        onSelected:
                            variant.availableStock <= 0 || _saving || _buying
                            ? null
                            : (_) => setState(() {
                                _selected = variant;
                                _quantity = 1;
                              }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                _selected == null
                    ? (product.inStock
                          ? 'Select an available option to view stock.'
                          : 'Currently out of stock.')
                    : '${_selected!.availableStock} available',
              ),
              const Divider(height: 40),
              Row(
                children: [
                  const Expanded(child: Text('Quantity')),
                  IconButton(
                    tooltip: 'Decrease quantity',
                    onPressed: !_saving && _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$_quantity'),
                  IconButton(
                    tooltip: 'Increase quantity',
                    onPressed:
                        !_saving &&
                            _selected != null &&
                            _quantity < _selected!.availableStock &&
                            _quantity < 99
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(product.description, style: const TextStyle(height: 1.7)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _selected == null || _saving || _buying
                      ? null
                      : _add,
                  child: Text(_saving ? 'Adding…' : 'Add to cart'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selected == null || _saving || _buying
                      ? null
                      : _buyNow,
                  child: const Text('Buy Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
