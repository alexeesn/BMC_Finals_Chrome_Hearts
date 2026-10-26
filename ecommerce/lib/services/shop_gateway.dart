import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog.dart';

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

abstract class ShopGateway {
  ShopIdentity? get currentUser;
  Stream<void> get authChanges;
  Future<List<CatalogProduct>> loadCatalog();
  Future<ShopAccount> loadAccount();
  Future<void> signIn(String email, String password);

  /// True means email confirmation is required before sign-in.
  Future<bool> signUp(String name, String email, String password);
  Future<void> signOut();
}

class SupabaseShopGateway implements ShopGateway {
  SupabaseShopGateway(this.client);
  final SupabaseClient client;
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
}
