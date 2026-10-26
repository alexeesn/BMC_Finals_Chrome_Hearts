import 'dart:typed_data';

import 'shopping.dart';

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.active,
    required this.sortOrder,
  });
  factory AdminCategory.fromJson(Map<String, dynamic> row) => AdminCategory(
    id: row['id'] as String,
    name: row['name'] as String,
    slug: row['slug'] as String,
    active: row['is_active'] as bool,
    sortOrder: (row['sort_order'] as num).toInt(),
  );
  final String id;
  final String name;
  final String slug;
  final bool active;
  final int sortOrder;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'is_active': active,
    'sort_order': sortOrder,
  };
}

class AdminImage {
  const AdminImage({
    required this.id,
    required this.path,
    required this.url,
    required this.sortOrder,
  });
  final String id;
  final String path;
  final String url;
  final int sortOrder;
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.description,
    required this.active,
    this.images = const [],
  });
  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String description;
  final bool active;
  final List<AdminImage> images;
  Map<String, dynamic> toJson() => {
    'id': id,
    'category_id': categoryId,
    'name': name,
    'slug': slug,
    'description': description,
    'is_active': active,
  };
}

class AdminVariant {
  const AdminVariant({
    this.id,
    required this.productId,
    required this.sku,
    required this.option,
    required this.priceMinor,
    required this.stock,
    required this.reserved,
    required this.active,
    this.updatedAt,
  });
  factory AdminVariant.fromJson(Map<String, dynamic> row) => AdminVariant(
    id: row['id'] as String,
    productId: row['product_id'] as String,
    sku: row['sku'] as String,
    option: row['option_label'] as String,
    priceMinor: (row['price_minor'] as num).toInt(),
    stock: (row['stock_on_hand'] as num).toInt(),
    reserved: (row['stock_reserved'] as num).toInt(),
    active: row['is_active'] as bool,
    updatedAt: row['updated_at'] as String,
  );
  final String? id;
  final String productId;
  final String sku;
  final String option;
  final int priceMinor;
  final int stock;
  final int reserved;
  final bool active;
  final String? updatedAt;
  int get available => stock - reserved;
}

class AdminCatalog {
  const AdminCatalog({
    required this.categories,
    required this.products,
    required this.variants,
  });
  final List<AdminCategory> categories;
  final List<AdminProduct> products;
  final List<AdminVariant> variants;
}

class AdminStats {
  const AdminStats(
    this.products,
    this.orders,
    this.paidOrders,
    this.pendingOrders,
  );
  final int products;
  final int orders;
  final int paidOrders;
  final int pendingOrders;
}

int? parsePesoInput(String value) {
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final minor =
      int.parse(match[1]!) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  return minor >= 1 && minor <= 1000000000 ? minor : null;
}

String? nextFulfillment(String paymentStatus, String fulfillmentStatus) {
  if (paymentStatus != 'paid') return null;
  return switch (fulfillmentStatus) {
    'preparing' => 'shipped',
    'shipped' => 'delivered',
    _ => null,
  };
}

class UploadImage {
  const UploadImage(this.bytes, this.mime, this.extension);
  final Uint8List bytes;
  final String mime;
  final String extension;
  factory UploadImage.validate(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ShoppingException('Choose an image up to 5 MB.');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return UploadImage(bytes, 'image/jpeg', 'jpg');
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      return UploadImage(bytes, 'image/png', 'png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return UploadImage(bytes, 'image/webp', 'webp');
    }
    throw const ShoppingException('Choose a JPEG, PNG, or WebP image.');
  }
}
