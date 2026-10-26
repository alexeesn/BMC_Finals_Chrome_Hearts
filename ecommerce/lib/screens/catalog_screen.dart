import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../services/shop_gateway.dart';
import '../services/cart_controller.dart';
import '../widgets/product_art.dart';
import '../widgets/collection_banner.dart';
import '../widgets/shop_layout.dart';
import 'product_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.gateway,
    required this.cart,
    required this.onViewCart,
    this.refreshToken = 0,
    this.active = true,
  });
  final ShopGateway gateway;
  final CartController cart;
  final VoidCallback onViewCart;
  final int refreshToken;
  final bool active;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<CatalogProduct>> _catalog;
  final _search = TextEditingController();
  String _category = 'All';
  @override
  void initState() {
    super.initState();
    _catalog = widget.gateway.loadCatalog();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _catalog = widget.gateway.loadCatalog();
    }
  }

  Future<void> _reload() async {
    final next = widget.gateway.loadCatalog();
    setState(() => _catalog = next);
    try {
      await next;
    } catch (_) {
      /* FutureBuilder displays retry. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'CH / COLLECTION',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'serif', letterSpacing: 2),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh catalog',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: FutureBuilder<List<CatalogProduct>>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ShopEmptyState(
                icon: Icons.wifi_off_outlined,
                title: 'The collection is taking a moment.',
                message: 'Unable to load the collection.',
                action: FilledButton(
                  onPressed: _reload,
                  child: const Text('Retry catalog'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snapshot.data!;
            final categories = [
              'All',
              ...({for (final p in all) p.category}.toList()..sort()),
            ];
            final activeCategory = categories.contains(_category)
                ? _category
                : 'All';
            final query = _search.text.trim().toLowerCase();
            final visible = all
                .where(
                  (p) =>
                      (activeCategory == 'All' ||
                          p.category == activeCategory) &&
                      '${p.name} ${p.category}'.toLowerCase().contains(query),
                )
                .toList();
            return RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CollectionBanner(active: widget.active),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search the collection',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () => setState(_search.clear),
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: categories
                                .map(
                                  (category) => ChoiceChip(
                                    label: Text(category),
                                    selected: activeCategory == category,
                                    onSelected: (_) =>
                                        setState(() => _category = category),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'The collection',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              Text(
                                '${visible.length} pieces',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text(
                              all.isEmpty
                                  ? 'The collection is coming soon.'
                                  : 'No products match your search.',
                            ),
                            if (all.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _category = 'All';
                                }),
                                child: const Text('Clear filters'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width < 300
                              ? 1
                              : width < 700
                              ? 2
                              : width < 960
                              ? 3
                              : 4;
                          final cardWidth =
                              (width - (columns - 1) * 16) / columns;
                          final scale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent:
                                      cardWidth * 1.16 + 146 * scale,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 20,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = visible[index];
                              return Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ProductScreen(
                                        product: product,
                                        cart: widget.cart,
                                        onViewCart: widget.onViewCart,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ProductArt(product: product),
                                            if (!product.inStock)
                                              Positioned(
                                                top: 12,
                                                right: 12,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  color: const Color(
                                                    0xee101012,
                                                  ),
                                                  child: const Text(
                                                    'Sold out',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.category.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xffaaa8a3),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              product.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'serif',
                                                fontSize: 20,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              product.startingPrice == null
                                                  ? 'Unavailable'
                                                  : formatPesos(
                                                      product.startingPrice!,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }, childCount: visible.length),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
