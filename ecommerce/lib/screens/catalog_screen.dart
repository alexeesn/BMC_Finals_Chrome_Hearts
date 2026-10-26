import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../services/shop_gateway.dart';
import '../widgets/product_art.dart';
import 'product_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.gateway});
  final ShopGateway gateway;
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
    body: FutureBuilder<List<CatalogProduct>>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load the collection.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _reload,
                  child: const Text('Retry catalog'),
                ),
              ],
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
                  (activeCategory == 'All' || p.category == activeCategory) &&
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xff1b1b1e),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xff373739)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE ARCHIVE',
                              style: TextStyle(fontSize: 11, letterSpacing: 3),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Silver soul.\nDark essentials.',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 34,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Explore the collection.',
                              style: TextStyle(color: Color(0xffaaa8a3)),
                            ),
                          ],
                        ),
                      ),
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
                      Text(
                        'Collection · ${visible.length}',
                        style: Theme.of(context).textTheme.titleLarge,
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
                    builder: (context, constraints) => SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.crossAxisExtent < 300
                            ? 1
                            : constraints.crossAxisExtent < 700
                            ? 2
                            : 3,
                        mainAxisExtent: 310,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = visible[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProductScreen(product: product),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: ProductArt(product: product)),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.category,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xffaaa8a3),
                                        ),
                                      ),
                                      Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 20,
                                        ),
                                      ),
                                      Text(
                                        product.startingPrice == null
                                            ? 'Unavailable'
                                            : formatPesos(
                                                product.startingPrice!,
                                              ),
                                      ),
                                      if (!product.inStock)
                                        const Text('Sold out'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: visible.length),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
