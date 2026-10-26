import 'catalog.dart';

class CartLine {
  const CartLine({
    required this.id,
    required this.variantId,
    required this.quantity,
    required this.revision,
    this.product,
    this.variant,
  });
  final String id;
  final String variantId;
  final int quantity;
  final int revision;
  final CatalogProduct? product;
  final CatalogVariant? variant;
  bool get available => variant != null && variant!.availableStock >= quantity;
  int? get subtotal => variant == null ? null : variant!.priceMinor * quantity;
}

class DeliveryAddress {
  const DeliveryAddress({
    this.id,
    required this.recipient,
    required this.phone,
    required this.province,
    required this.city,
    required this.barangay,
    required this.street,
    required this.postalCode,
    this.instructions = '',
    this.isDefault = false,
  });
  factory DeliveryAddress.fromJson(Map<String, dynamic> row) => DeliveryAddress(
    id: row['id'] as String,
    recipient: row['recipient'] as String,
    phone: row['phone'] as String,
    province: row['province'] as String,
    city: row['city'] as String,
    barangay: row['barangay'] as String,
    street: row['street'] as String,
    postalCode: row['postal_code'] as String,
    instructions: row['instructions'] as String,
    isDefault: row['is_default'] as bool,
  );
  final String? id;
  final String recipient;
  final String phone;
  final String province;
  final String city;
  final String barangay;
  final String street;
  final String postalCode;
  final String instructions;
  final bool isDefault;
  String get fullAddress => '$street, $barangay, $city, $province $postalCode';
  Map<String, dynamic> toFields() => {
    'recipient': recipient,
    'phone': phone,
    'province': province,
    'city': city,
    'barangay': barangay,
    'street': street,
    'postal_code': postalCode,
    'instructions': instructions,
  };
}

/// Safe feedback for expected validation/concurrency errors.
class ShoppingException implements Exception {
  const ShoppingException(this.message);
  final String message;
}
