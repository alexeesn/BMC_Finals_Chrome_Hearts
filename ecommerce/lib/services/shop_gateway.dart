import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog.dart';
import '../models/shopping.dart';
import '../models/checkout.dart';
import '../models/order.dart';
import 'checkout_attempt_store.dart';
import 'order_placement.dart';

class ShopIdentity {
  const ShopIdentity(this.id, this.email);
  final String id;
  final String email;
}

class ShopAccount {
  const ShopAccount({required this.displayName, required this.isAdmin});
  final String displayName;
  final bool isAdmin;
}

abstract class ShopGateway implements OrderGateway {
  ShopIdentity? get currentUser;
  @override
  String? get orderUserId => currentUser?.id;
  Stream<void> get authChanges;
  Future<List<CatalogProduct>> loadCatalog();
  Future<ShopAccount> loadAccount();
  Future<void> signIn(String email, String password);

  /// True means email confirmation is required before sign-in.
  Future<bool> signUp(String name, String email, String password);
  Future<void> signOut();
  Future<List<CartLine>> loadCart();
  Future<void> addToCart(String variantId, int quantity);
  Future<void> updateCartQuantity(CartLine line, int quantity);
  Future<void> removeCartLine(CartLine line);
  Future<List<DeliveryAddress>> loadAddresses();
  Future<void> saveAddress(DeliveryAddress address);
  Future<void> deleteAddress(String id);
  Future<void> setDefaultAddress(String id);
  Future<CheckoutQuote> quoteCheckout(
    CheckoutSelection selection,
    String addressId,
  );
  Future<ShopOrder> loadOrder(String id);
  Future<List<ShopOrder>> loadOrders();
}

class SupabaseShopGateway extends ShopGateway {
  SupabaseShopGateway(this.client);
  final SupabaseClient client;
  final _attempts = CheckoutAttemptStore();
  @override
  ShopIdentity? get currentUser {
    final user = client.auth.currentUser;
    return user == null ? null : ShopIdentity(user.id, user.email ?? '');
  }

  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});

  @override
  Future<List<CatalogProduct>> loadCatalog() async {
    // Safe availability view has no inferred FK; fetch it separately.
    final results = await Future.wait([
      client
          .from('products')
          .select(
            'id,name,description,categories!inner(name,is_active),'
            'product_images(storage_path,sort_order)',
          )
          .eq('is_active', true)
          .eq('categories.is_active', true)
          .order('name'),
      client
          .from('catalog_variants')
          .select('id,product_id,option_label,price_minor,available_stock')
          .order('price_minor')
          .order('option_label'),
    ]);
    final grouped = <String, List<CatalogVariant>>{};
    for (final row in results[1]) {
      (grouped[row['product_id'] as String] ??= []).add(
        CatalogVariant.fromJson(row),
      );
    }
    return results[0].map((row) {
      final images =
          List<Map<String, dynamic>>.from(row['product_images'] as List)..sort(
            (a, b) =>
                (a['sort_order'] as num).compareTo(b['sort_order'] as num),
          );
      return CatalogProduct(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String,
        category: (row['categories'] as Map<String, dynamic>)['name'] as String,
        variants: grouped[row['id']] ?? [],
        imageUrls: images
            .map(
              (image) => client.storage
                  .from('product-images')
                  .getPublicUrl(image['storage_path'] as String),
            )
            .toList(),
      );
    }).toList();
  }

  @override
  Future<ShopAccount> loadAccount() async {
    final id = currentUser?.id;
    if (id == null) throw StateError('Sign in first.');
    final rows = await Future.wait([
      client.from('profiles').select('display_name').eq('id', id).single(),
      client.from('user_roles').select('role').eq('user_id', id).single(),
    ]);
    return ShopAccount(
      displayName: rows[0]['display_name'] as String,
      isAdmin: rows[1]['role'] == 'admin',
    );
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp(String name, String email, String password) async {
    final result = await client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
    );
    return result.session == null;
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);

  String _requireUser() {
    final id = currentUser?.id;
    if (id == null) throw const ShoppingException('Please sign in first.');
    return id;
  }

  @override
  Future<List<CartLine>> loadCart() async {
    final userId = _requireUser();
    final rows = await client
        .from('cart_items')
        .select('id,variant_id,quantity,revision')
        .eq('user_id', userId)
        .order('updated_at');
    final catalog = await loadCatalog();
    final variants = <String, CatalogVariant>{};
    final products = <String, CatalogProduct>{};
    for (final product in catalog) {
      for (final variant in product.variants) {
        variants[variant.id] = variant;
        products[variant.id] = product;
      }
    }
    return rows
        .map(
          (row) => CartLine(
            id: row['id'] as String,
            variantId: row['variant_id'] as String,
            quantity: (row['quantity'] as num).toInt(),
            revision: (row['revision'] as num).toInt(),
            product: products[row['variant_id']],
            variant: variants[row['variant_id']],
          ),
        )
        .toList();
  }

  Future<void> _validateQuantity(String variantId, int quantity) async {
    if (quantity < 1 || quantity > 99) {
      throw const ShoppingException('Quantity must be between 1 and 99.');
    }
    final variant = await client
        .from('catalog_variants')
        .select('available_stock')
        .eq('id', variantId)
        .maybeSingle();
    if (variant == null || (variant['available_stock'] as num) < quantity) {
      throw const ShoppingException(
        'Not enough stock. Refresh your cart and choose a lower quantity.',
      );
    }
  }

  @override
  Future<void> addToCart(String variantId, int quantity) async {
    final userId = _requireUser();
    if (quantity < 1 || quantity > 99) {
      throw const ShoppingException('Quantity must be between 1 and 99.');
    }
    final existing = await client
        .from('cart_items')
        .select('id,quantity,revision')
        .eq('user_id', userId)
        .eq('variant_id', variantId)
        .maybeSingle();
    final total = quantity + ((existing?['quantity'] as num?)?.toInt() ?? 0);
    await _validateQuantity(variantId, total);
    if (existing == null) {
      try {
        await client.from('cart_items').insert({
          'user_id': userId,
          'variant_id': variantId,
          'quantity': quantity,
        });
      } on PostgrestException catch (error) {
        if (error.code == '23505') {
          throw const ShoppingException(
            'Cart changed on another device. Refresh and try again.',
          );
        }
        rethrow;
      }
    } else {
      final changed = await client
          .from('cart_items')
          .update({'quantity': total})
          .eq('id', existing['id'])
          .eq('user_id', userId)
          .eq('revision', existing['revision'])
          .select('id');
      if (changed.isEmpty) {
        throw const ShoppingException(
          'Cart changed on another device. Refresh and try again.',
        );
      }
    }
  }

  @override
  Future<void> updateCartQuantity(CartLine line, int quantity) async {
    final userId = _requireUser();
    await _validateQuantity(line.variantId, quantity);
    final changed = await client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', line.id)
        .eq('user_id', userId)
        .eq('revision', line.revision)
        .select('id');
    if (changed.isEmpty) {
      throw const ShoppingException(
        'Cart changed. Refresh before editing again.',
      );
    }
  }

  @override
  Future<void> removeCartLine(CartLine line) async {
    final changed = await client
        .from('cart_items')
        .delete()
        .eq('id', line.id)
        .eq('user_id', _requireUser())
        .eq('revision', line.revision)
        .select('id');
    if (changed.isEmpty) {
      throw const ShoppingException(
        'Cart changed. Refresh before removing this item.',
      );
    }
  }

  @override
  Future<List<DeliveryAddress>> loadAddresses() async {
    final rows = await client
        .from('addresses')
        .select()
        .eq('user_id', _requireUser())
        .order('is_default', ascending: false)
        .order('created_at');
    return rows.map(DeliveryAddress.fromJson).toList();
  }

  @override
  Future<void> saveAddress(DeliveryAddress address) async {
    final userId = _requireUser();
    if (address.id == null) {
      await client.from('addresses').insert({
        'user_id': userId,
        ...address.toFields(),
      });
    } else {
      final rows = await client
          .from('addresses')
          .update(address.toFields())
          .eq('id', address.id!)
          .eq('user_id', userId)
          .select('id');
      if (rows.isEmpty) {
        throw const ShoppingException(
          'Address no longer exists. Refresh the list.',
        );
      }
    }
  }

  @override
  Future<void> deleteAddress(String id) async {
    await client
        .from('addresses')
        .delete()
        .eq('id', id)
        .eq('user_id', _requireUser());
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    _requireUser();
    await client.rpc('set_default_address', params: {'p_address': id});
  }

  @override
  Future<CheckoutQuote> quoteCheckout(
    CheckoutSelection selection,
    String addressId,
  ) async {
    _requireUser();
    try {
      final result = await client.rpc(
        'quote_checkout',
        params: {
          'p_source': selection.source,
          'p_address': addressId,
          'p_items': selection.items,
        },
      );
      return CheckoutQuote.fromJson(Map<String, dynamic>.from(result as Map));
    } on PostgrestException catch (error) {
      if (error.code == '22023' || error.code == '42501') {
        throw ShoppingException(error.message);
      }
      rethrow;
    }
  }

  @override
  Future<CheckoutAttempt?> loadCheckoutAttempt() =>
      _attempts.read(_requireUser());
  @override
  Future<void> saveCheckoutAttempt(CheckoutAttempt attempt) =>
      _attempts.save(_requireUser(), attempt);
  @override
  Future<void> clearCheckoutAttempt(String expectedKey) =>
      _attempts.clear(_requireUser(), expectedKey);

  static const _orderFields =
      'id,user_id,order_number,idempotency_key,payment_status,fulfillment_status,'
      'subtotal_minor,shipping_minor,total_minor,created_at,expires_at,delivery_address,'
      'order_items(product_name,option_label,quantity,unit_price_minor,line_total_minor)';

  @override
  Future<ShopOrder?> findOrderByCheckoutKey(String key) async {
    final row = await client
        .from('orders')
        .select('id')
        .eq('user_id', _requireUser())
        .eq('idempotency_key', key)
        .maybeSingle();
    return row == null ? null : loadOrder(row['id'] as String);
  }

  @override
  Future<ShopOrder> loadOrder(String id) async {
    // Keep the explicit customer filter even for a signed-in admin.
    final row = await client
        .from('orders')
        .select(_orderFields)
        .eq('id', id)
        .eq('user_id', _requireUser())
        .single();
    final payment = await client
        .from('order_payment_summary')
        .select('state,payment_url,expires_at')
        .eq('order_id', id)
        .maybeSingle();
    return ShopOrder.fromJson(row, payment);
  }

  @override
  Future<List<ShopOrder>> loadOrders() async {
    final rows = await client
        .from('orders')
        .select(_orderFields)
        .eq('user_id', _requireUser())
        .order('created_at', ascending: false)
        .limit(50);
    if (rows.isEmpty) return [];
    final payments = await client
        .from('order_payment_summary')
        .select('order_id,state,payment_url,expires_at')
        .inFilter('order_id', rows.map((row) => row['id']).toList());
    final byOrder = {
      for (final payment in payments) payment['order_id']: payment,
    };
    return rows
        .map((row) => ShopOrder.fromJson(row, byOrder[row['id']]))
        .toList();
  }

  @override
  Future<void> requestPayment(CheckoutAttempt attempt) async {
    _requireUser();
    try {
      await client.functions
          .invoke('create-payment', body: attempt.toJson())
          .timeout(const Duration(seconds: 45));
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] is String
          ? (details['error'] as String).substring(
              0,
              (details['error'] as String).length.clamp(0, 180),
            )
          : 'Unable to confirm checkout (HTTP ${error.status}). Check My orders before retrying.';
      throw PaymentRequestException(error.status, message);
    }
  }
}
