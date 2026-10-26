import 'package:flutter/material.dart';

import '../models/catalog.dart';

class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.product});
  final CatalogProduct product;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xff232326),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            switch (product.category.toLowerCase()) {
              'clothing' => Icons.checkroom_outlined,
              'jewelry' => Icons.diamond_outlined,
              _ => Icons.shopping_bag_outlined,
            },
            size: 58,
            color: const Color(0xffaaa8a3),
          ),
          const SizedBox(height: 12),
          const Text(
            'IMAGE COMING SOON',
            style: TextStyle(fontSize: 10, letterSpacing: 1.5),
          ),
        ],
      ),
    );
    if (product.imageUrls.isEmpty) return fallback;
    return Image.network(
      product.imageUrls.first,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}
