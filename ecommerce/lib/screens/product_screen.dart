import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/checkout.dart';
import 'checkout_screen.dart';
import '../services/cart_controller.dart';
import '../widgets/product_art.dart';
import '../widgets/shop_layout.dart';
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
  int _imageIndex = 0;
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

  Widget _gallery(CatalogProduct product) => Column(
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ProductArt(
                product: product,
                imageUrl: product.imageUrls.isEmpty
                    ? null
                    : product.imageUrls[_imageIndex],
              ),
              if (product.imageUrls.length > 1)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: const Color(0xdd101012),
                    child: Text(
                      '${_imageIndex + 1} / ${product.imageUrls.length}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (product.imageUrls.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: product.imageUrls
                .asMap()
                .entries
                .map(
                  (entry) => Semantics(
                    button: true,
                    selected: _imageIndex == entry.key,
                    label: 'View product image ${entry.key + 1}',
                    child: InkWell(
                      onTap: () => setState(() => _imageIndex = entry.key),
                      child: Container(
                        width: 60,
                        height: 68,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _imageIndex == entry.key
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: ProductArt(
                            product: product,
                            imageUrl: entry.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );

  Widget _details(CatalogProduct product) {
    final price = _selected?.priceMinor ?? product.startingPrice;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShopHeading(eyebrow: product.category, title: product.name),
        const SizedBox(height: 16),
        if (_selected == null && product.variants.length > 1)
          Text(
            'Starting from',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        Text(
          price == null ? 'Unavailable' : formatPesos(price),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        ShopPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT AN OPTION',
                style: TextStyle(fontSize: 11, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: product.variants
                    .map(
                      (variant) => ChoiceChip(
                        label: Text(
                          '${variant.label}${variant.availableStock <= 0 ? ' · Sold out' : ''}',
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
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShopPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Expanded(child: Text('Quantity')),
              IconButton(
                tooltip: 'Decrease quantity',
                onPressed: !_saving && !_buying && _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  semanticsLabel: 'Quantity $_quantity',
                ),
              ),
              IconButton(
                tooltip: 'Increase quantity',
                onPressed:
                    !_saving &&
                        !_buying &&
                        _selected != null &&
                        _quantity < _selected!.availableStock &&
                        _quantity < 99
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const Divider(height: 48),
        Text('About this piece', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          product.description.isEmpty
              ? 'Explore the available options above.'
              : product.description,
          style: TextStyle(
            height: 1.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        actions: [
          IconButton(
            tooltip: 'View cart',
            onPressed: _saving || _buying
                ? null
                : () {
                    widget.onViewCart();
                    Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 800
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _gallery(product)),
                        const SizedBox(width: 40),
                        Expanded(flex: 5, child: _details(product)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _gallery(product),
                        const SizedBox(height: 28),
                        _details(product),
                      ],
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: ShopFooter(
        maxWidth: 1120,
        child: LayoutBuilder(
          builder: (context, box) {
            final add = OutlinedButton(
              onPressed: _selected == null || _saving || _buying ? null : _add,
              child: Text(_saving ? 'Adding…' : 'Add to cart'),
            );
            final buy = FilledButton(
              onPressed: _selected == null || _saving || _buying
                  ? null
                  : _buyNow,
              child: const Text('Buy Now'),
            );
            if (box.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(14) > 19) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [add, const SizedBox(height: 10), buy],
              );
            }
            return Row(
              children: [
                Expanded(child: add),
                const SizedBox(width: 12),
                Expanded(child: buy),
              ],
            );
          },
        ),
      ),
    );
  }
}
