import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shopping.dart';
import 'shop_gateway.dart';

class CartController extends ChangeNotifier {
  CartController(this.gateway) {
    _owner = gateway.currentUser?.id;
    _subscription = gateway.authChanges.listen((_) {
      if (_owner == gateway.currentUser?.id) return;
      _owner = gateway.currentUser?.id;
      _session++;
      _request++;
      lines = const [];
      error = null;
      busy = false;
      loading = false;
      notifyListeners();
      unawaited(refresh());
    }, onError: (Object _) {});
    unawaited(refresh());
  }
  final ShopGateway gateway;
  late final StreamSubscription<void> _subscription;
  String? _owner;
  int _session = 0;
  int _request = 0;
  bool _disposed = false;
  List<CartLine> lines = const [];
  bool loading = false;
  bool busy = false;
  String? error;
  int get count => lines.fold(0, (total, row) => total + row.quantity);

  Future<void> refresh() async {
    if (_disposed) return;
    final request = ++_request;
    if (_owner == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await gateway.loadCart();
      if (!_disposed &&
          request == _request &&
          _owner == gateway.currentUser?.id) {
        lines = List.unmodifiable(result);
      }
    } catch (_) {
      if (!_disposed && request == _request) {
        error = 'Unable to load your cart. Please retry.';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _change(Future<void> Function() operation) async {
    if (gateway.currentUser?.id == null || gateway.currentUser?.id != _owner) {
      throw const ShoppingException('Please sign in again.');
    }
    if (busy) {
      throw const ShoppingException('Please wait for your cart update.');
    }
    final session = _session;
    busy = true;
    notifyListeners();
    try {
      await operation();
      if (_disposed || session != _session) {
        throw const ShoppingException(
          'Account changed. Please check your current cart.',
        );
      }
      await refresh();
    } finally {
      if (!_disposed && session == _session) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> add(String variantId, int quantity) =>
      _change(() => gateway.addToCart(variantId, quantity));
  Future<void> update(CartLine line, int quantity) =>
      _change(() => gateway.updateCartQuantity(line, quantity));
  Future<void> remove(CartLine line) =>
      _change(() => gateway.removeCartLine(line));

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
