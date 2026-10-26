import 'package:flutter/material.dart';

import 'screens/account_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/cart_screen.dart';
import 'services/shop_gateway.dart';
import 'services/cart_controller.dart';

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
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xffd9d6cf),
          brightness: Brightness.dark,
          primary: const Color(0xffd9d6cf),
          onPrimary: const Color(0xff101012),
          surface: const Color(0xff151517),
          onSurface: const Color(0xfff2f0eb),
        ).copyWith(
          secondary: const Color(0xffbdbbb5),
          onSecondary: const Color(0xff101012),
          secondaryContainer: const Color(0xff303034),
          onSecondaryContainer: const Color(0xfff2f0eb),
          surfaceContainerHighest: const Color(0xff262629),
          surfaceContainerHigh: const Color(0xff202023),
          surfaceContainer: const Color(0xff1b1b1e),
          surfaceContainerLow: const Color(0xff151517),
          onSurfaceVariant: const Color(0xffaaa8a3),
          outline: const Color(0xff66666b),
          outlineVariant: const Color(0xff303034),
        );
    final baseText = ThemeData(brightness: Brightness.dark).textTheme;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return MaterialApp(
      title: 'CH / Collection',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xff0d0d0f),
        textTheme: baseText.copyWith(
          headlineLarge: const TextStyle(
            fontFamily: 'serif',
            fontSize: 36,
            height: 1.15,
            color: Color(0xfff2f0eb),
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'serif',
            fontSize: 26,
            height: 1.2,
            color: Color(0xfff2f0eb),
          ),
          titleLarge: const TextStyle(
            fontFamily: 'serif',
            fontSize: 23,
            height: 1.3,
            color: Color(0xfff2f0eb),
          ),
          bodyMedium: baseText.bodyMedium?.copyWith(height: 1.5),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xff0d0d0f),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            color: colors.onSurface,
          ),
          shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
        dividerTheme: DividerThemeData(color: colors.outlineVariant),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xff111113),
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xff303034),
          elevation: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colors.surface,
          selectedColor: colors.primary,
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: TextStyle(color: colors.onSurface),
          secondaryLabelStyle: TextStyle(color: colors.onPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: buttonShape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: buttonShape,
          ),
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
  int _catalogVersion = 0;
  late final _cart = CartController(widget.gateway);
  @override
  void dispose() {
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _tab,
      children: [
        CatalogScreen(
          gateway: widget.gateway,
          cart: _cart,
          onViewCart: () => setState(() => _tab = 1),
          refreshToken: _catalogVersion,
          active: _tab == 0,
        ),
        CartScreen(
          cart: _cart,
          onViewCollection: () => setState(() => _tab = 0),
        ),
        AccountScreen(
          gateway: widget.gateway,
          onOrdersClosed: _cart.refresh,
          onAdminClosed: () async {
            if (mounted) setState(() => _catalogVersion++);
            await _cart.refresh();
          },
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: 'Collection',
        ),
        NavigationDestination(
          icon: AnimatedBuilder(
            animation: _cart,
            builder: (context, _) => Badge(
              isLabelVisible: _cart.count > 0,
              label: Text('${_cart.count}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          label: 'Cart',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );
}
