// Standalone checks for admin input and allowed fulfillment actions.
import 'dart:convert';
import 'dart:typed_data';

import 'package:ecommerce/models/admin.dart';
import 'package:ecommerce/models/shopping.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void rejects(Uint8List bytes) {
  try {
    UploadImage.validate(bytes);
  } on ShoppingException {
    return;
  }
  throw StateError('Unsupported or oversized image should be rejected');
}

void main() {
  check(parsePesoInput('12000.50') == 1200050, 'Exact PHP centavo conversion');
  check(parsePesoInput('0.01') == 1, 'Minimum price');
  check(parsePesoInput('10000000.00') == 1000000000, 'Maximum supported price');
  for (final input in [
    '0',
    '-1',
    '1.001',
    '1e3',
    'NaN',
    '10000000.01',
    '1,000.00',
  ]) {
    check(parsePesoInput(input) == null, 'Reject invalid price: $input');
  }
  check(
    nextFulfillment('paid', 'preparing') == 'shipped',
    'Paid preparing order can ship',
  );
  check(
    nextFulfillment('paid', 'shipped') == 'delivered',
    'Shipped order can deliver',
  );
  check(
    nextFulfillment('paid', 'delivered') == null,
    'No backward action after delivery',
  );
  for (final status in ['pending', 'expired', 'cancelled', 'needs_review']) {
    check(
      nextFulfillment(status, 'preparing') == null,
      'Cannot fulfill unpaid/review order: $status',
    );
  }
  final jpeg = UploadImage.validate(Uint8List.fromList([255, 216, 255, 224]));
  check(jpeg.mime == 'image/jpeg' && jpeg.extension == 'jpg', 'JPEG signature');
  check(
    UploadImage.validate(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]))
            .mime ==
        'image/png',
    'PNG signature',
  );
  check(
    UploadImage.validate(
          Uint8List.fromList([
            ...ascii.encode('RIFF'),
            0,
            0,
            0,
            0,
            ...ascii.encode('WEBP'),
          ]),
        ).mime ==
        'image/webp',
    'WebP signature',
  );
  rejects(Uint8List(0));
  rejects(Uint8List.fromList(utf8.encode('<svg><script>bad()</script></svg>')));
  rejects(Uint8List(5 * 1024 * 1024 + 1));
  final variant = AdminVariant.fromJson({
    'id': 'variant',
    'product_id': 'product',
    'sku': 'SKU',
    'option_label': 'M',
    'price_minor': 12345,
    'stock_on_hand': 5,
    'stock_reserved': 2,
    'is_active': true,
    'updated_at': '2026-10-26T01:02:03.123456+00:00',
  });
  check(variant.available == 3, 'Available stock excludes reservations');
  check(
    variant.updatedAt == '2026-10-26T01:02:03.123456+00:00',
    'Keep exact stock concurrency timestamp',
  );
  // ignore: avoid_print
  print(
    'PASS: exact admin prices, supported image signatures/limits, reserved stock, timestamps, and forward paid fulfillment.',
  );
}
