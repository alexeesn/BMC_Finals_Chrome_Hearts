import 'package:flutter/material.dart';

import '../../models/admin.dart';
import '../../models/catalog.dart';
import '../../services/product_image_picker.dart';
import '../../services/shop_gateway.dart';
import '../../widgets/shopping_feedback.dart';
import 'admin_guard.dart';
import 'admin_forms.dart';

class AdminProductScreen extends StatefulWidget {
  const AdminProductScreen({
    super.key,
    required this.shop,
    required this.productId,
  });
  final ShopGateway shop;
  final String productId;
  @override
  State<AdminProductScreen> createState() => _AdminProductScreenState();
}

class _AdminProductScreenState extends State<AdminProductScreen> {
  late Future<AdminCatalog> _data = widget.shop.admin.loadCatalog();
  bool _busy = false;
  Future<void> _refresh() async {
    final future = widget.shop.admin.loadCatalog();
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {
      /* FutureBuilder shows retry. */
    }
  }

  Future<void> _edit(WidgetBuilder builder) async {
    await openAdminPage<Object?>(context, widget.shop, builder);
    if (mounted) await _refresh();
  }

  Future<void> _upload(AdminProduct product, {AdminImage? replacing}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = await pickProductImage();
      if (image == null || !mounted) return;
      final sortOrder = product.images.isEmpty
          ? 0
          : product.images
                    .map((image) => image.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      await widget.shop.admin.uploadImage(
        product.id,
        image,
        sortOrder,
        replacing: replacing,
      );
      if (mounted) {
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Product image saved')));
        }
      }
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Manage product'),
      actions: [
        IconButton(
          tooltip: 'Refresh product',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<AdminCatalog>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this product.'),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry product'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        final product = catalog.products
            .where((product) => product.id == widget.productId)
            .firstOrNull;
        if (product == null) {
          return const Center(child: Text('Product not found.'));
        }
        final variants = catalog.variants
            .where((variant) => variant.productId == product.id)
            .toList();
        final blocked =
            _busy || snapshot.connectionState != ConnectionState.done;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (blocked) const LinearProgressIndicator(),
                Text(
                  product.name,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 32),
                ),
                Text(product.active ? 'Published' : 'Draft / archived'),
                Text(product.slug),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: blocked
                      ? null
                      : () => _edit(
                          (_) => AdminProductForm(
                            shop: widget.shop,
                            catalog: catalog,
                            product: product,
                          ),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit details / visibility'),
                ),
                const Divider(height: 32),
                Text('Images', style: Theme.of(context).textTheme.titleLarge),
                const Text('JPEG, PNG, or WebP · up to 5 MB each'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: blocked ? null : () => _upload(product),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Upload image'),
                ),
                if (product.images.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No product images yet.'),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: product.images
                      .asMap()
                      .entries
                      .map(
                        (entry) => SizedBox(
                          width: 180,
                          child: Card(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 150,
                                  width: 180,
                                  child: Image.network(
                                    entry.value.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                                Text(
                                  entry.key == 0
                                      ? 'Cover image'
                                      : 'Image ${entry.key + 1}',
                                ),
                                TextButton(
                                  onPressed: blocked
                                      ? null
                                      : () => _upload(
                                          product,
                                          replacing: entry.value,
                                        ),
                                  child: const Text('Replace image'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const Divider(height: 32),
                Text(
                  'Variants and stock',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                OutlinedButton.icon(
                  onPressed: blocked
                      ? null
                      : () => _edit(
                          (_) => AdminVariantForm(
                            shop: widget.shop,
                            productId: product.id,
                          ),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add variant'),
                ),
                if (variants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Add at least one active variant before publishing.',
                    ),
                  ),
                ...variants.map(
                  (variant) => Card(
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(
                        '${variant.option} · ${formatPesos(variant.priceMinor)}',
                      ),
                      subtitle: Text(
                        '${variant.sku} · ${variant.active ? 'Active' : 'Archived'}\nOn hand: ${variant.stock} · Reserved: ${variant.reserved} · Available: ${variant.available}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: blocked
                          ? null
                          : () => _edit(
                              (_) => AdminVariantForm(
                                shop: widget.shop,
                                productId: product.id,
                                variant: variant,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
