// Standalone pure-Dart checks, also usable when the Flutter engine cannot start.
// Run: dart run test/order_model_checks.dart
import 'dart:async';

import 'package:ecommerce/models/order.dart';
import 'package:ecommerce/models/shopping.dart';
import 'package:ecommerce/services/order_placement.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

class PlacementFake implements OrderGateway {
  @override
  String? orderUserId = 'customer';
  CheckoutAttempt? cached;
  ShopOrder? result;
  ShopOrder? commitBeforeError;
  bool cacheFails = false;
  Object? requestError;
  int requests = 0;
  final requestedKeys = <String>[];
  Completer<void>? gate;
  @override
  Future<CheckoutAttempt?> loadCheckoutAttempt() async => cached;
  @override
  Future<void> saveCheckoutAttempt(CheckoutAttempt attempt) async {
    if (cacheFails) throw StateError('Recovery cache unavailable');
    cached = attempt;
  }

  @override
  Future<void> clearCheckoutAttempt(String key) async {
    if (cached?.key == key) cached = null;
  }

  @override
  Future<ShopOrder?> findOrderByCheckoutKey(String key) async => result;
  @override
  Future<void> requestPayment(CheckoutAttempt attempt) async {
    requests++;
    requestedKeys.add(attempt.key);
    await gate?.future;
    result = commitBeforeError;
    if (requestError != null) throw requestError!;
  }
}

Future<Object> rejected(Future<Object?> result) async {
  try {
    await result;
  } catch (error) {
    return error;
  }
  throw StateError('Expected operation to reject');
}

Future<void> checkPlacement(ShopOrder canonical) async {
  const request = CheckoutAttempt(
    key: 'checkout',
    source: 'buy_now',
    addressId: 'address',
    items: [
      {'variant_id': 'variant', 'quantity': 1},
    ],
  );
  final lostResponse = PlacementFake()
    ..commitBeforeError = canonical
    ..requestError = TimeoutException('Lost response');
  final recovered = await placeOrResumeOrder(lostResponse, request);
  check(
    recovered.id == canonical.id && !recovered.paid,
    'Lost response recovers backend order without inventing payment',
  );
  await placeOrResumeOrder(lostResponse, request);
  check(
    lostResponse.requests == 1,
    'Committed order never recreates its provider session',
  );

  final uncertain = PlacementFake()..requestError = TimeoutException('Offline');
  check(
    await rejected(placeOrResumeOrder(uncertain, request)) is ShoppingException,
    'Unconfirmed checkout remains recoverable',
  );
  check(
    uncertain.cached?.key == request.key,
    'Unconfirmed request keeps its original key',
  );
  final changed = CheckoutAttempt(
    key: 'new-key',
    source: request.source,
    addressId: request.addressId,
    items: request.items,
  );
  await rejected(placeOrResumeOrder(uncertain, changed));
  check(
    uncertain.requests == 1,
    'A different request cannot overwrite an unresolved checkout',
  );
  uncertain
    ..requestError = null
    ..commitBeforeError = canonical;
  await placeOrResumeOrder(uncertain, request);
  check(
    uncertain.requestedKeys.length == 2 &&
        uncertain.requestedKeys.every((key) => key == request.key),
    'Retry uses the original idempotency key',
  );

  final noCache = PlacementFake()..cacheFails = true;
  await rejected(placeOrResumeOrder(noCache, request));
  check(noCache.requests == 0, 'No provider request when recovery-save fails');

  final badSelection = PlacementFake()
    ..requestError = const PaymentRequestException(400, 'Not enough stock');
  check(
    await rejected(placeOrResumeOrder(badSelection, request))
        is CheckoutRejected,
    'Confirmed selection rejection is editable',
  );
  check(
    badSelection.cached == null,
    'Rejected request with no order releases its cache',
  );

  final switched = PlacementFake()
    ..gate = Completer<void>()
    ..commitBeforeError = canonical;
  final running = placeOrResumeOrder(switched, request);
  while (switched.requests == 0) {
    await Future<void>.delayed(Duration.zero);
  }
  switched.orderUserId = 'different-customer';
  final failure = rejected(running);
  switched.gate!.complete();
  check(
    await failure is ShoppingException,
    'Changed account cannot receive the previous customer order',
  );
  check(
    switched.cached?.key == request.key,
    'Old account can still recover its checkout',
  );
}

Future<void> main() async {
  for (final url in [
    'https://dev.xen.to/demo',
    'https://checkout-staging.xendit.co/demo',
  ]) {
    check(
      trustedTestPaymentUri(url) != null,
      'Allow hosted test payment: $url',
    );
  }
  for (final url in [
    'http://dev.xen.to/demo',
    'https://checkout.xendit.co/demo',
    'https://dev.xen.to.evil.example/demo',
    'https://dev.xen.to@evil.example/demo',
    'https://user:pass@dev.xen.to/demo',
    'https://dev.xen.to:444/demo',
    'javascript:alert(1)',
  ]) {
    check(
      trustedTestPaymentUri(url) == null,
      'Reject unexpected destination: $url',
    );
  }
  ShopOrder order(String status, String state, DateTime expiry) =>
      ShopOrder.fromJson(
        {
          'id': 'order',
          'user_id': 'customer',
          'order_number': 'BMC-DEMO',
          'idempotency_key': 'checkout',
          'payment_status': status,
          'fulfillment_status': 'unfulfilled',
          'subtotal_minor': 1200000,
          'shipping_minor': 15000,
          'total_minor': 1215000,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'expires_at': expiry.toIso8601String(),
          'delivery_address': {
            'recipient': 'Demo',
            'phone': '09123456789',
            'province': 'Metro Manila',
            'city': 'Quezon City',
            'barangay': 'Sample',
            'street': 'Demo Street',
            'postal_code': '1100',
            'instructions': '',
          },
          'order_items': <Map<String, dynamic>>[],
        },
        {
          'state': state,
          'expires_at': expiry.toIso8601String(),
          'payment_url': 'https://dev.xen.to/demo',
        },
      );
  final future = DateTime.now().add(const Duration(minutes: 5));
  check(
    order('pending', 'active', future).canPay,
    'Active pending order can open payment',
  );
  check(
    !order('pending', 'active', future).paid,
    'Payment link cannot imply paid',
  );
  check(
    !order('paid', 'active', future).paid,
    'Inconsistent status is not confirmed paid',
  );
  check(order('paid', 'paid', future).paid, 'Both backend states confirm paid');
  check(
    !order('pending', 'unknown', future).canPay,
    'Unknown creation cannot open payment',
  );
  check(
    !order(
      'pending',
      'active',
      DateTime.now().subtract(const Duration(minutes: 1)),
    ).canPay,
    'Elapsed payment window cannot open payment',
  );
  check(
    !order('expired', 'active', future).canPay,
    'Terminal order cannot open payment',
  );
  final original = CheckoutAttempt.fromJson({
    'idempotency_key': 'key',
    'source': 'buy_now',
    'address_id': 'address',
    'items': [
      {'variant_id': 'variant', 'quantity': 2},
    ],
  });
  final restored = CheckoutAttempt.fromJson(original.toJson());
  check(
    restored.key == original.key && restored.items.single['quantity'] == 2,
    'Recovery request preserves key and payload',
  );
  await checkPlacement(order('pending', 'active', future));
  // ignore: avoid_print
  print(
    'PASS: payment URL restrictions, backend-only paid state, payment eligibility, and idempotent checkout recovery.',
  );
}
