import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/shop_gateway.dart';

class AdminGuard extends StatefulWidget {
  const AdminGuard({super.key, required this.shop, required this.builder});
  final ShopGateway shop;
  final WidgetBuilder builder;
  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  String? _owner;
  Future<ShopAccount>? _access;
  StreamSubscription<void>? _subscription;
  @override
  void initState() {
    super.initState();
    _load();
    _subscription = widget.shop.authChanges.listen((_) {
      if (mounted && widget.shop.currentUser?.id != _owner) setState(_load);
    }, onError: (Object _) {});
  }

  void _load() {
    _owner = widget.shop.currentUser?.id;
    _access = _owner == null ? null : widget.shop.loadAccount();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_owner == null || widget.shop.currentUser?.id != _owner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin panel')),
        body: const Center(
          child: Text('Sign in with an admin account to continue.'),
        ),
      );
    }
    return FutureBuilder<ShopAccount>(
      key: ValueKey(_owner),
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin panel')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to check admin access.'),
                  TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('Retry access'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data?.isAdmin != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin panel')),
            body: const Center(child: Text('Admin access is required.')),
          );
        }
        return KeyedSubtree(
          key: ValueKey(_owner),
          child: Builder(builder: widget.builder),
        );
      },
    );
  }
}

Future<T?> openAdminPage<T>(
  BuildContext context,
  ShopGateway shop,
  WidgetBuilder builder,
) => Navigator.of(context).push<T>(
  MaterialPageRoute<T>(
    builder: (_) => AdminGuard(shop: shop, builder: builder),
  ),
);
