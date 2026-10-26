import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/admin.dart';
import '../models/order.dart';
import '../models/shopping.dart';
import 'admin_gateway.dart';

class SupabaseAdminGateway implements AdminGateway {
  SupabaseAdminGateway(this.client);
  final SupabaseClient client;

  Future<String> _requireAdmin() async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const ShoppingException('Sign in with an admin account.');
    }
    final role = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', owner)
        .single();
    _sameOwner(owner);
    if (role['role'] != 'admin') {
      throw const ShoppingException('Admin access is required.');
    }
    return owner;
  }

  void _sameOwner(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw const ShoppingException(
        'Account changed. Open the admin panel again.',
      );
    }
  }

  Future<T> _edit<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PostgrestException catch (error) {
      if (error.code == '40001' || error.code == '22023') {
        throw ShoppingException(error.message);
      }
      if (error.code == '23505') {
        throw const ShoppingException(
          'That slug, SKU, or variant option already exists. Refresh before retrying.',
        );
      }
      if (error.code == '23514') {
        throw const ShoppingException(
          'Check the price and stock. Stock cannot be lower than active reservations.',
        );
      }
      if (error.code == '42501') {
        throw const ShoppingException(
          'Admin permission is required. Sign in again if your role changed.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<AdminStats> loadStats() async {
    final owner = await _requireAdmin();
    final counts = await Future.wait<int>([
      client.from('products').count(),
      client.from('orders').count(),
      client.from('orders').count().eq('payment_status', 'paid'),
      client.from('orders').count().eq('payment_status', 'pending'),
    ]);
    _sameOwner(owner);
    return AdminStats(counts[0], counts[1], counts[2], counts[3]);
  }

  @override
  Future<AdminCatalog> loadCatalog() async {
    final owner = await _requireAdmin();
    final rows = await Future.wait<dynamic>([
      client
          .from('categories')
          .select()
          .order('sort_order')
          .order('name')
          .limit(1000),
      client
          .from('products')
          .select(
            'id,category_id,name,slug,description,is_active,product_images(id,storage_path,sort_order)',
          )
          .order('name')
          .limit(1000),
      client.rpc('admin_variants'),
    ]);
    _sameOwner(owner);
    return AdminCatalog(
      categories: (rows[0] as List)
          .map((row) => AdminCategory.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      products: (rows[1] as List).map((row) {
        final images =
            (row['product_images'] as List)
                .map(
                  (image) => AdminImage(
                    id: image['id'] as String,
                    path: image['storage_path'] as String,
                    url: client.storage
                        .from('product-images')
                        .getPublicUrl(image['storage_path'] as String),
                    sortOrder: (image['sort_order'] as num).toInt(),
                  ),
                )
                .toList()
              ..sort((a, b) {
                final order = a.sortOrder.compareTo(b.sortOrder);
                return order != 0 ? order : a.id.compareTo(b.id);
              });
        return AdminProduct(
          id: row['id'] as String,
          categoryId: row['category_id'] as String,
          name: row['name'] as String,
          slug: row['slug'] as String,
          description: row['description'] as String,
          active: row['is_active'] as bool,
          images: images,
        );
      }).toList(),
      variants: (rows[2] as List)
          .map((row) => AdminVariant.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }

  @override
  Future<void> saveCategory(AdminCategory category) => _edit(() async {
    final owner = await _requireAdmin();
    _sameOwner(owner);
    await client.from('categories').upsert(category.toJson());
  });
  @override
  Future<void> saveProduct(AdminProduct product) => _edit(() async {
    final owner = await _requireAdmin();
    _sameOwner(owner);
    await client.from('products').upsert(product.toJson());
  });
  @override
  Future<void> saveVariant(AdminVariant variant) => _edit(() async {
    final owner = await _requireAdmin();
    _sameOwner(owner);
    await client.rpc(
      'admin_save_variant_checked',
      params: {
        'p_id': variant.id,
        'p_product': variant.productId,
        'p_sku': variant.sku,
        'p_option': variant.option,
        'p_price': variant.priceMinor,
        'p_stock': variant.stock,
        'p_active': variant.active,
        'p_expected_updated_at': variant.updatedAt,
      },
    );
  });
  @override
  Future<void> uploadImage(
    String productId,
    UploadImage image,
    int sortOrder, {
    AdminImage? replacing,
  }) => _edit(() async {
    final owner = await _requireAdmin();
    final valid = UploadImage.validate(image.bytes);
    final path = '$productId/${const Uuid().v4()}.${valid.extension}';
    _sameOwner(owner);
    await client.storage
        .from('product-images')
        .uploadBinary(
          path,
          valid.bytes,
          fileOptions: FileOptions(
            contentType: valid.mime,
            upsert: false,
            cacheControl: '3600',
          ),
        );
    _sameOwner(owner);
    if (replacing == null) {
      await client.from('product_images').insert({
        'id': const Uuid().v4(),
        'product_id': productId,
        'storage_path': path,
        'sort_order': sortOrder,
      });
    } else {
      final rows = await client
          .from('product_images')
          .update({'storage_path': path})
          .eq('id', replacing.id)
          .eq('product_id', productId)
          .select('id');
      if (rows.isEmpty) {
        throw const ShoppingException(
          'Image changed or was removed. Refresh this product.',
        );
      }
    }
    // Old files are retained intentionally so order-linked image snapshots stay valid.
  });

  @override
  Future<List<ShopOrder>> loadOrders({
    required int offset,
    String? paymentStatus,
  }) async {
    final owner = await _requireAdmin();
    var query = client.from('orders').select(orderSelectFields);
    if (paymentStatus != null) {
      query = query.eq('payment_status', paymentStatus);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 29);
    if (rows.isEmpty) return [];
    final payments = await client
        .from('order_payment_summary')
        .select('order_id,state,payment_url,expires_at')
        .inFilter('order_id', rows.map((row) => row['id']).toList());
    _sameOwner(owner);
    final byOrder = {for (final row in payments) row['order_id']: row};
    return rows
        .map((row) => ShopOrder.fromJson(row, byOrder[row['id']]))
        .toList();
  }

  @override
  Future<ShopOrder> loadOrder(String id) async {
    final owner = await _requireAdmin();
    final row = await client
        .from('orders')
        .select(orderSelectFields)
        .eq('id', id)
        .single();
    final payment = await client
        .from('order_payment_summary')
        .select('state,payment_url,expires_at')
        .eq('order_id', id)
        .maybeSingle();
    _sameOwner(owner);
    return ShopOrder.fromJson(row, payment);
  }

  @override
  Future<void> updateFulfillment(String orderId, String status) =>
      _edit(() async {
        final owner = await _requireAdmin();
        _sameOwner(owner);
        await client.rpc(
          'admin_update_fulfillment',
          params: {'p_order': orderId, 'p_status': status},
        );
      });
}
