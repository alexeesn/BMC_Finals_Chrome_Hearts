import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../widgets/product_art.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.product});
  final CatalogProduct product;
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  CatalogVariant? _selected;
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
                        onSelected: variant.availableStock <= 0
                            ? null
                            : (_) => setState(() => _selected = variant),
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
              Text(product.description, style: const TextStyle(height: 1.7)),
            ],
          ),
        ),
      ),
    );
  }
}
