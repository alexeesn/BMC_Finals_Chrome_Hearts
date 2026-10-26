import 'package:flutter/material.dart';

import '../../models/admin.dart';
import '../../services/shop_gateway.dart';
import 'admin_guard.dart';
import 'admin_forms.dart';
import 'admin_product_screen.dart';

class AdminCatalogScreen extends StatefulWidget {
  const AdminCatalogScreen({super.key, required this.shop});
  final ShopGateway shop;
  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> {
  late Future<AdminCatalog> _data = widget.shop.admin.loadCatalog();
  final _search = TextEditingController();
  bool _categories = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.shop.admin.loadCatalog();
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {
      /* FutureBuilder shows retry. */
    }
  }

  Future<void> _product(AdminCatalog catalog, [AdminProduct? product]) async {
    if (product == null) {
      final id = await openAdminPage<String>(
        context,
        widget.shop,
        (_) => AdminProductForm(shop: widget.shop, catalog: catalog),
      );
      if (!mounted) return;
      await _refresh();
      if (id != null && mounted) {
        await openAdminPage<void>(
          context,
          widget.shop,
          (_) => AdminProductScreen(shop: widget.shop, productId: id),
        );
      }
    } else {
      await openAdminPage<void>(
        context,
        widget.shop,
        (_) => AdminProductScreen(shop: widget.shop, productId: product.id),
      );
    }
    if (mounted) await _refresh();
  }

  Future<void> _category([AdminCategory? category]) async {
    await openAdminPage<void>(
      context,
      widget.shop,
      (_) => AdminCategoryForm(shop: widget.shop, category: category),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminCatalog>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load the admin catalog.'),
              TextButton(
                onPressed: _refresh,
                child: const Text('Retry catalog'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final catalog = snapshot.data!;
      final query = _search.text.trim().toLowerCase();
      final products = catalog.products
          .where((p) => '${p.name} ${p.slug}'.toLowerCase().contains(query))
          .toList();
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Products'),
                  selected: !_categories,
                  onSelected: (_) => setState(() => _categories = false),
                ),
                ChoiceChip(
                  label: const Text('Categories'),
                  selected: _categories,
                  onSelected: (_) => setState(() => _categories = true),
                ),
                IconButton(
                  tooltip: 'Refresh catalog',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_categories) ...[
              FilledButton.icon(
                onPressed: () => _category(),
                icon: const Icon(Icons.add),
                label: const Text('Add category'),
              ),
              ...catalog.categories.map(
                (c) => Card(
                  child: ListTile(
                    onTap: () => _category(c),
                    title: Text(c.name),
                    subtitle: Text(
                      '${c.slug} · ${c.active ? 'Active' : 'Archived'}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: catalog.categories.isEmpty
                    ? null
                    : () => _product(catalog),
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
              if (catalog.categories.isEmpty)
                const Text('Add a category before adding products.'),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search products',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              if (products.isEmpty) const Text('No products found.'),
              ...products.map(
                (p) => Card(
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => _product(catalog, p),
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.slug} · ${p.active ? 'Active' : 'Draft / archived'}',
                        ),
                        leading: p.images.isEmpty
                            ? const Icon(Icons.image_outlined)
                            : SizedBox(
                                width: 48,
                                height: 56,
                                child: Image.network(
                                  p.images.first.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _product(catalog, p),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Photos & stock'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
