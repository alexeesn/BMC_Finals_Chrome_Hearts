import 'checkout.dart';
import 'shopping.dart';

const orderSelectFields =
    'id,user_id,order_number,idempotency_key,payment_status,fulfillment_status,'
    'subtotal_minor,shipping_minor,total_minor,created_at,expires_at,delivery_address,'
    'order_items(product_name,option_label,quantity,unit_price_minor,line_total_minor)';

class CheckoutAttempt {
  const CheckoutAttempt({
    required this.key,
    required this.source,
    required this.addressId,
    required this.items,
  });
  factory CheckoutAttempt.fromJson(Map<String, dynamic> row) => CheckoutAttempt(
    key: row['idempotency_key'] as String,
    source: row['source'] as String,
    addressId: row['address_id'] as String,
    items: List.unmodifiable(
      (row['items'] as List).map(
        (item) => Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.from(item as Map),
        ),
      ),
    ),
  );
  final String key;
  final String source;
  final String addressId;
  final List<Map<String, dynamic>> items;
  Map<String, dynamic> toJson() => {
    'idempotency_key': key,
    'source': source,
    'address_id': addressId,
    'items': items,
  };
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.ownerId,
    required this.number,
    required this.checkoutKey,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.paymentState,
    required this.subtotalMinor,
    required this.shippingMinor,
    required this.totalMinor,
    required this.createdAt,
    required this.expiresAt,
    required this.address,
    required this.items,
    this.paymentUrl,
  });
  factory ShopOrder.fromJson(
    Map<String, dynamic> row,
    Map<String, dynamic>? payment,
  ) => ShopOrder(
    id: row['id'] as String,
    ownerId: row['user_id'] as String,
    number: row['order_number'] as String,
    checkoutKey: row['idempotency_key'] as String,
    paymentStatus: row['payment_status'] as String,
    fulfillmentStatus: row['fulfillment_status'] as String,
    paymentState: payment?['state'] as String? ?? 'unknown',
    subtotalMinor: (row['subtotal_minor'] as num).toInt(),
    shippingMinor: (row['shipping_minor'] as num).toInt(),
    totalMinor: (row['total_minor'] as num).toInt(),
    createdAt: DateTime.parse(row['created_at'] as String),
    expiresAt: DateTime.parse(
      (payment?['expires_at'] ?? row['expires_at']) as String,
    ),
    address: DeliveryAddress.fromJson({
      ...Map<String, dynamic>.from(row['delivery_address'] as Map),
      'id': '',
      'is_default': false,
    }),
    items: (row['order_items'] as List)
        .map(
          (item) => QuotedItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    paymentUrl: payment?['payment_url'] as String?,
  );
  final String id;
  final String ownerId;
  final String number;
  final String checkoutKey;
  final String paymentStatus;
  final String fulfillmentStatus;
  final String paymentState;
  final int subtotalMinor;
  final int shippingMinor;
  final int totalMinor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DeliveryAddress address;
  final List<QuotedItem> items;
  final String? paymentUrl;
  bool get paid => paymentStatus == 'paid' && paymentState == 'paid';
  bool get pending => paymentStatus == 'pending';
  bool get canPay =>
      pending &&
      paymentState == 'active' &&
      paymentUrl != null &&
      expiresAt.isAfter(DateTime.now());
}

Uri? trustedTestPaymentUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !{'dev.xen.to', 'checkout-staging.xendit.co'}.contains(uri.host)) {
    return null;
  }
  return uri;
}

class PaymentRequestException implements Exception {
  const PaymentRequestException(this.status, this.message);
  final int status;
  final String message;
}

class CheckoutRejected extends ShoppingException {
  const CheckoutRejected(super.message);
}
