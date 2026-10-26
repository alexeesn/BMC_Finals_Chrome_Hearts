class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.label,
    required this.priceMinor,
    required this.availableStock,
  });
  factory CatalogVariant.fromJson(Map<String, dynamic> json) => CatalogVariant(
    id: json['id'] as String,
    label: json['option_label'] as String,
    priceMinor: (json['price_minor'] as num).toInt(),
    availableStock: (json['available_stock'] as num).toInt(),
  );
  final String id;
  final String label;
  final int priceMinor;
  final int availableStock;
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.variants,
    this.imageUrls = const [],
  });
  final String id;
  final String name;
  final String description;
  final String category;
  final List<CatalogVariant> variants;
  final List<String> imageUrls;
  int? get startingPrice => variants.isEmpty
      ? null
      : variants.map((v) => v.priceMinor).reduce((a, b) => a < b ? a : b);
  bool get inStock => variants.any((v) => v.availableStock > 0);
}

String formatPesos(int minor) {
  final digits = (minor ~/ 100).toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '₱$grouped.${(minor % 100).toString().padLeft(2, '0')}';
}
