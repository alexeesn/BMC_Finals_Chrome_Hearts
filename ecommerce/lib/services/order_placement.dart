import '../models/order.dart';
import '../models/shopping.dart';

abstract interface class OrderGateway {
  String? get orderUserId;
  Future<CheckoutAttempt?> loadCheckoutAttempt();
  Future<void> saveCheckoutAttempt(CheckoutAttempt attempt);
  Future<void> clearCheckoutAttempt(String expectedKey);
  Future<ShopOrder?> findOrderByCheckoutKey(String key);
  Future<void> requestPayment(CheckoutAttempt attempt);
}

/// Reuse one frozen request/key. Never retry provider creation with a new key.
Future<ShopOrder> placeOrResumeOrder(
  OrderGateway gateway,
  CheckoutAttempt attempt,
) async {
  final owner = gateway.orderUserId;
  void checkOwner() {
    if (owner == null || gateway.orderUserId != owner) {
      throw const ShoppingException(
        'Account changed. Return to My orders after signing in.',
      );
    }
  }

  checkOwner();
  final previous = await gateway.loadCheckoutAttempt();
  checkOwner();
  if (previous != null && previous.key != attempt.key) {
    throw const ShoppingException(
      'Resume your unfinished checkout from My orders first.',
    );
  }
  await gateway.saveCheckoutAttempt(attempt);
  checkOwner();
  var order = await gateway.findOrderByCheckoutKey(attempt.key);
  checkOwner();
  if (order == null || order.paymentState == 'reserved') {
    Object? requestError;
    try {
      await gateway.requestPayment(attempt);
    } catch (error) {
      requestError = error;
    }
    checkOwner();
    // A timeout can hide a committed order: always read before deciding to retry.
    order = await gateway.findOrderByCheckoutKey(attempt.key);
    checkOwner();
    if (order == null) {
      if (requestError is PaymentRequestException &&
          requestError.status == 400) {
        await gateway.clearCheckoutAttempt(attempt.key);
        throw CheckoutRejected(requestError.message);
      }
      throw ShoppingException(
        requestError is PaymentRequestException ? requestError.message : 'Checkout result is not confirmed yet. Retry this same checkout or check My orders.',
      );
    }
  }
  if (order.paymentState != 'reserved') {
    // A failed local-cache cleanup must not hide the canonical order.
    try {
      await gateway.clearCheckoutAttempt(attempt.key);
    } catch (_) {
      /* Retry cleanup on next resume. */
    }
  }
  checkOwner();
  return order;
}
