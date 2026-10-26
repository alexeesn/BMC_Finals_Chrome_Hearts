import 'package:flutter/material.dart';

import 'screens/account_screen.dart';
import 'screens/catalog_screen.dart';
import 'services/shop_gateway.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.gateway,
    this.startupFailed = false,
    this.onRetry,
  });
  final ShopGateway? gateway;
  final bool startupFailed;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xffd9d6cf),
      brightness: Brightness.dark,
      primary: const Color(0xffd9d6cf),
      onPrimary: const Color(0xff101012),
      surface: const Color(0xff1b1b1e),
      onSurface: const Color(0xfff2f0eb),
    );
    return MaterialApp(
      title: 'CH / Collection',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xff101012),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xff101012)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 50)),
        ),
      ),
      home: gateway != null
          ? ShopShell(gateway: gateway!)
          : Scaffold(
              body: Center(
                child: startupFailed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Unable to start the shop. Please try again.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
    );
  }
}

class ShopShell extends StatefulWidget {
  const ShopShell({super.key, required this.gateway});
  final ShopGateway gateway;
  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _tab,
      children: [
        CatalogScreen(gateway: widget.gateway),
        AccountScreen(gateway: widget.gateway),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: 'Collection',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );
}
