import 'dart:async';

import 'package:flutter/material.dart';

import '../services/shop_gateway.dart';
import 'auth_screen.dart';
import 'addresses_screen.dart';
import 'orders_screen.dart';
import 'admin/admin_guard.dart';
import 'admin/admin_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.gateway,
    this.onOrdersClosed,
    this.onAdminClosed,
  });
  final ShopGateway gateway;
  final Future<void> Function()? onOrdersClosed;
  final Future<void> Function()? onAdminClosed;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  StreamSubscription<void>? _subscription;
  Future<ShopAccount>? _account;
  String? _userId;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscription = widget.gateway.authChanges.listen(
      (_) {
        if (mounted) setState(_refresh);
      },
      onError: (Object _) {
        // Keep the current UI; the SDK handles token-refresh/network recovery.
      },
    );
  }

  void _refresh() {
    final id = widget.gateway.currentUser?.id;
    if (id != _userId || _account == null) {
      _userId = id;
      _account = id == null ? null : widget.gateway.loadAccount();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.gateway.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.gateway.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.person_outline, size: 64),
          const SizedBox(height: 24),
          if (user == null) ...[
            const Text(
              'Your collection starts here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign in or create an account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AuthScreen(gateway: widget.gateway),
                ),
              ),
              child: const Text('Sign in / Register'),
            ),
          ] else ...[
            Text(user.email, textAlign: TextAlign.center),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('My orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrdersScreen(gateway: widget.gateway),
                  ),
                );
                await widget.onOrdersClosed?.call();
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('My addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddressesScreen(gateway: widget.gateway),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<ShopAccount>(
              key: ValueKey(user.id),
              future: _userId == user.id ? _account : null,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text('Unable to load your account.'),
                      TextButton(
                        onPressed: () => setState(
                          () => _account = widget.gateway.loadAccount(),
                        ),
                        child: const Text('Retry account'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final account = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName.isEmpty
                              ? 'My account'
                              : account.displayName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              account.isAdmin
                                  ? Icons.verified_user_outlined
                                  : Icons.person_outline,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              account.isAdmin
                                  ? 'Admin account'
                                  : 'Customer account',
                            ),
                          ],
                        ),
                        if (account.isAdmin)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                            title: const Text('Admin panel'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await openAdminPage<void>(
                                context,
                                widget.gateway,
                                (_) => AdminScreen(shop: widget.gateway),
                              );
                              await widget.onAdminClosed?.call();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _signingOut ? null : _signOut,
              child: Text(_signingOut ? 'Signing out…' : 'Sign out'),
            ),
          ],
        ],
      ),
    );
  }
}
