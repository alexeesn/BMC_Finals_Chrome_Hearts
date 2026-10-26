import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/checkout.dart';
import 'checkout_screen.dart';
import '../services/cart_controller.dart';
import '../widgets/product_art.dart';
import '../widgets/shop_layout.dart';
import '../widgets/shop_navigation.dart';
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
        aspectRatio: 1.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
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
                  left: 20,
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
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.category.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          product.name,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 27,
            height: 1.15,
          ),
        ),
      ],
    );
    final amount = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selected == null && product.variants.length > 1)
          Text(
            'From',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        Text(
          price == null ? 'Unavailable' : formatPesos(price),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 12), amount],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 12),
                amount,
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('Size / option', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: product.variants
              .map(
                (variant) => ChoiceChip(
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  label: Text(
                    '${variant.label}${variant.availableStock <= 0 ? ' · Sold out' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: variant.availableStock <= 0
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  selected: _selected?.id == variant.id,
                  onSelected: variant.availableStock <= 0 || _saving || _buying
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
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text('Quantity', style: TextStyle(fontSize: 12)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Decrease quantity',
                    onPressed: !_saving && !_buying && _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove, size: 17),
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
                    icon: const Icon(Icons.add, size: 17),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 40),
        const Text(
          'Description',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          product.description.isEmpty
              ? 'Explore the available options above.'
              : product.description,
          style: TextStyle(
            fontSize: 12,
            height: 1.7,
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
        toolbarHeight: 70,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: ShopHeaderButton(
              icon: Icons.arrow_back,
              tooltip: 'Back to home',
              onPressed: _saving || _buying
                  ? null
                  : () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'THE DETAILS',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        actions: [
          ShopCartButton(
            cart: widget.cart,
            onPressed: _saving || _buying
                ? null
                : () {
                    widget.onViewCart();
                    Navigator.of(context).pop();
                  },
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 800
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _gallery(product)),
                          const SizedBox(width: 40),
                          Expanded(flex: 5, child: _details(product)),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _gallery(product),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: _details(product),
                        ),
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
            if (box.maxWidth < 300 ||
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
