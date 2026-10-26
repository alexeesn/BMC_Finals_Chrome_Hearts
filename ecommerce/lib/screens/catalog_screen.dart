import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../services/shop_gateway.dart';
import '../services/cart_controller.dart';
import '../widgets/product_art.dart';
import '../widgets/collection_banner.dart';
import '../widgets/shop_layout.dart';
import '../widgets/shop_navigation.dart';
import 'product_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.gateway,
    required this.cart,
    required this.onViewCart,
    this.refreshToken = 0,
    this.active = true,
    this.categoryRequest = 0,
  });
  final ShopGateway gateway;
  final CartController cart;
  final VoidCallback onViewCart;
  final int refreshToken;
  final bool active;
  final int categoryRequest;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<CatalogProduct>> _catalog;
  final _search = TextEditingController();
  final _categoriesKey = GlobalKey();
  final _productsKey = GlobalKey();
  final _firstCategory = FocusNode();
  bool _pendingCategories = false;
  String _category = 'All';
  @override
  void initState() {
    super.initState();
    _catalog = widget.gateway.loadCatalog();
  }

  @override
  void dispose() {
    _search.dispose();
    _firstCategory.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _catalog = widget.gateway.loadCatalog();
    }
    if (widget.categoryRequest != oldWidget.categoryRequest) {
      _pendingCategories = true;
    }
    if (widget.active && _pendingCategories) _revealCategories();
  }

  void _revealCategories() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active || !_pendingCategories) return;
      final target = _categoriesKey.currentContext;
      if (target == null) return;
      _pendingCategories = false;
      Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
      );
      _firstCategory.requestFocus();
    });
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

  void _browse() {
    final target = _productsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 70 * (MediaQuery.textScalerOf(context).scale(14) / 14),
      titleSpacing: 20,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CH / COLLECTION',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
              color: Color(0xffd9d6cf),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Objects. Apparel. Everyday.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              color: Color(0xffaaa8a3),
            ),
          ),
        ],
      ),
      actions: [
        ShopCartButton(cart: widget.cart, onPressed: widget.onViewCart),
        const SizedBox(width: 20),
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
            if (_pendingCategories) _revealCategories();
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'FIND YOUR NEXT PIECE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Color(0xffaaa8a3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search the collection',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () => setState(_search.clear),
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          CollectionBanner(
                            active: widget.active,
                            onBrowse: _browse,
                          ),
                          const SizedBox(height: 18),
                          SingleChildScrollView(
                            key: _categoriesKey,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(right: 7),
                                      child: ChoiceChip(
                                        focusNode: entry.key == 0
                                            ? _firstCategory
                                            : null,
                                        showCheckmark: false,
                                        label: Text(
                                          entry.value,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 9,
                                        ),
                                        selected: activeCategory == entry.value,
                                        onSelected: (_) => setState(
                                          () => _category = entry.value,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            key: _productsKey,
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'The edit',
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
                              (width - (columns - 1) * 12) / columns;
                          final scale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent:
                                      cardWidth * 1.12 + 104 * scale,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 22,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = visible[index];
                              return Material(
                                color: Colors.transparent,
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
                                            Container(
                                              foregroundDecoration:
                                                  BoxDecoration(
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xff323235,
                                                      ),
                                                    ),
                                                  ),
                                              child: ProductArt(
                                                product: product,
                                              ),
                                            ),
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
                                        padding: const EdgeInsets.only(top: 9),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.category.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                letterSpacing: 1,
                                                color: Color(0xffaaa8a3),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              product.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              product.startingPrice == null
                                                  ? 'Unavailable'
                                                  : formatPesos(
                                                      product.startingPrice!,
                                                    ),
                                              style: const TextStyle(
                                                fontSize: 12,
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
