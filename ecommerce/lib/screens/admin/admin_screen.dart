import 'package:flutter/material.dart';

import '../../models/admin.dart';
import '../../services/shop_gateway.dart';
import 'admin_catalog_screen.dart';
import 'admin_orders_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.shop});
  final ShopGateway shop;
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;
  late Future<AdminStats> _stats = widget.shop.admin.loadStats();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin panel')),
    body: _tab == 0
        ? ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Store overview',
                style: TextStyle(fontFamily: 'serif', fontSize: 32),
              ),
              const SizedBox(height: 20),
              FutureBuilder<AdminStats>(
                future: _stats,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        const Text('Unable to load the overview.'),
                        TextButton(
                          onPressed: () => setState(
                            () => _stats = widget.shop.admin.loadStats(),
                          ),
                          child: const Text('Retry overview'),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stats = snapshot.data!;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Stat('Products', stats.products),
                      _Stat('Orders', stats.orders),
                      _Stat('Paid orders', stats.paidOrders),
                      _Stat('Pending orders', stats.pendingOrders),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => setState(() => _tab = 1),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Manage catalog'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _tab = 2),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Manage orders'),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _stats = widget.shop.admin.loadStats()),
                child: const Text('Refresh overview'),
              ),
            ],
          )
        : _tab == 1
        ? AdminCatalogScreen(shop: widget.shop)
        : AdminOrdersScreen(shop: widget.shop),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Catalog',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_shipping_outlined),
          label: 'Orders',
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.count);
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: Theme.of(context).textTheme.headlineLarge),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
