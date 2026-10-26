import 'package:flutter/material.dart';

import '../models/catalog.dart';

class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.product, this.imageUrl});
  final CatalogProduct product;
  final String? imageUrl;
  @override
  Widget build(BuildContext context) {
    final fallback = LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 120 || constraints.maxHeight < 110;
        return Semantics(
          image: true,
          label: 'Product image unavailable for ${product.name}',
          child: ColoredBox(
            color: const Color(0xff232326),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        switch (product.category.toLowerCase()) {
                          'clothing' => Icons.checkroom_outlined,
                          'jewelry' => Icons.diamond_outlined,
                          _ => Icons.shopping_bag_outlined,
                        },
                        size: compact ? 32 : 58,
                        color: const Color(0xffaaa8a3),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'IMAGE COMING SOON',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontSize: 10, letterSpacing: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (product.imageUrls.isEmpty && imageUrl == null) return fallback;
    return Image.network(
      imageUrl ?? product.imageUrls.first,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}
