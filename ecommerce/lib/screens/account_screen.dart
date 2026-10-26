import 'dart:async';

import 'package:flutter/material.dart';

import '../services/shop_gateway.dart';
import '../widgets/shop_layout.dart';
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

  Widget _link({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = widget.gateway.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const ShopHeading(
                eyebrow: 'The personal archive',
                title: 'Your collection.\nYour space.',
                subtitle:
                    'Your pieces, orders, and delivery details in one place.',
              ),
              const SizedBox(height: 28),
              if (user == null)
                ShopPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.person_outline, size: 40),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your collection starts here.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text('Sign in or create an account.'),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AuthScreen(gateway: widget.gateway),
                          ),
                        ),
                        child: const Text('Sign in / Register'),
                      ),
                    ],
                  ),
                )
              else ...[
                ShopPanel(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIGNED IN',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(letterSpacing: 2),
                            ),
                            const SizedBox(height: 4),
                            Text(user.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ShopPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      _link(
                        icon: Icons.receipt_long_outlined,
                        title: 'My orders',
                        subtitle: 'Follow your purchases and deliveries.',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  OrdersScreen(gateway: widget.gateway),
                            ),
                          );
                          await widget.onOrdersClosed?.call();
                        },
                      ),
                      const Divider(height: 1),
                      _link(
                        icon: Icons.location_on_outlined,
                        title: 'My addresses',
                        subtitle: 'Save your preferred delivery locations.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AddressesScreen(gateway: widget.gateway),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<ShopAccount>(
                  key: ValueKey(user.id),
                  future: _userId == user.id ? _account : null,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ShopPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unable to load your account.'),
                            TextButton(
                              onPressed: () => setState(
                                () => _account = widget.gateway.loadAccount(),
                              ),
                              child: const Text('Retry account'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final account = snapshot.data!;
                    return ShopPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROFILE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(letterSpacing: 2),
                          ),
                          const SizedBox(height: 12),
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
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  account.isAdmin
                                      ? 'Admin account'
                                      : 'Customer account',
                                ),
                              ),
                            ],
                          ),
                          if (account.isAdmin) ...[
                            const Divider(height: 32),
                            _link(
                              icon: Icons.admin_panel_settings_outlined,
                              title: 'Admin panel',
                              subtitle:
                                  'Manage your catalog, stock, and orders.',
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
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _signingOut ? null : _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(_signingOut ? 'Signing out…' : 'Sign out'),
                ),
              ],
              const SizedBox(height: 36),
              Text(
                'CH / COLLECTION',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 3,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
