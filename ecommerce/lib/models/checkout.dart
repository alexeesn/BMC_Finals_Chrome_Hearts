import 'shopping.dart';

class CheckoutSelection {
  CheckoutSelection.buyNow(String variantId, int quantity)
    : source = 'buy_now',
      items = List.unmodifiable([
        Map<String, dynamic>.unmodifiable({
          'variant_id': variantId,
          'quantity': quantity,
        }),
      ]);
  CheckoutSelection.cart(Iterable<String> ids)
    : source = 'cart',
      items = List.unmodifiable(
        ids.map(
          (id) => Map<String, dynamic>.unmodifiable({'cart_item_id': id}),
        ),
      );
  final String source;
  final List<Map<String, dynamic>> items;
}

class CheckoutQuote {
  const CheckoutQuote({
    required this.subtotalMinor,
    required this.shippingMinor,
    required this.totalMinor,
    required this.address,
    required this.items,
  });
  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    final delivery = Map<String, dynamic>.from(json['delivery_address'] as Map);
    return CheckoutQuote(
      subtotalMinor: (json['subtotal_minor'] as num).toInt(),
      shippingMinor: (json['shipping_minor'] as num).toInt(),
      totalMinor: (json['total_minor'] as num).toInt(),
      address: DeliveryAddress.fromJson({
        ...delivery,
        'id': json['address_id'],
        'is_default': false,
      }),
      items: (json['items'] as List)
          .map(
            (row) => QuotedItem.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
    );
  }
  final int subtotalMinor;
  final int shippingMinor;
  final int totalMinor;
  final DeliveryAddress address;
  final List<QuotedItem> items;
}

class QuotedItem {
  const QuotedItem({
    required this.name,
    required this.option,
    required this.quantity,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });
  factory QuotedItem.fromJson(Map<String, dynamic> row) => QuotedItem(
    name: row['product_name'] as String,
    option: row['option_label'] as String,
    quantity: (row['quantity'] as num).toInt(),
    unitPriceMinor: (row['unit_price_minor'] as num).toInt(),
    lineTotalMinor: (row['line_total_minor'] as num).toInt(),
  );
  final String name;
  final String option;
  final int quantity;
  final int unitPriceMinor;
  final int lineTotalMinor;
}
