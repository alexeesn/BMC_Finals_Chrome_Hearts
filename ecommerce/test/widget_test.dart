import 'dart:async';

import 'package:ecommerce/app.dart';
import 'package:ecommerce/models/catalog.dart';
import 'package:ecommerce/models/shopping.dart';
import 'package:ecommerce/services/cart_controller.dart';
import 'package:ecommerce/screens/addresses_screen.dart';
import 'package:ecommerce/screens/auth_screen.dart';
import 'package:ecommerce/services/shop_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const tee = CatalogProduct(
  id: 'tee',
  name: 'Archive Tee',
  description: 'Demo cotton tee.',
  category: 'Clothing',
  variants: [
    CatalogVariant(id: 'm', label: 'M', priceMinor: 1200000, availableStock: 6),
    CatalogVariant(
      id: 'xl',
      label: 'XL',
      priceMinor: 1200000,
      availableStock: 0,
    ),
  ],
);
const ring = CatalogProduct(
  id: 'ring',
  name: 'Silver Band',
  description: 'Demo ring.',
  category: 'Jewelry',
  variants: [
    CatalogVariant(
      id: '8',
      label: 'US 8',
      priceMinor: 1800000,
      availableStock: 2,
    ),
  ],
);

class FakeShop extends ShopGateway {
  final events = StreamController<void>.broadcast();
  ShopIdentity? identity;
  bool catalogFails = false;
  bool confirmEmail = true;
  int signInCalls = 0;
  int signUpCalls = 0;
  final carts = <String, List<CartLine>>{};
  final addresses = <String, List<DeliveryAddress>>{};
  Future<List<CartLine>>? delayedCart;
  bool mutationFails = false;
  int addressSaves = 0;
  @override
  ShopIdentity? get currentUser => identity;
  @override
  Stream<void> get authChanges => events.stream;
  @override
  Future<List<CatalogProduct>> loadCatalog() async {
    if (catalogFails) throw StateError('Offline');
    return [tee, ring];
  }

  @override
  Future<ShopAccount> loadAccount() async => ShopAccount(
    displayName: identity!.id == 'admin' ? 'Shop owner' : 'Customer',
    isAdmin: identity!.id == 'admin',
  );
  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    identity = ShopIdentity('admin', email);
    events.add(null);
  }

  @override
  Future<bool> signUp(String name, String email, String password) async {
    signUpCalls++;
    return confirmEmail;
  }

  @override
  Future<void> signOut() async {
    identity = null;
    events.add(null);
  }

  @override
  Future<List<CartLine>> loadCart() async {
    final response = delayedCart;
    delayedCart = null;
    return response ?? List.of(carts[identity?.id] ?? []);
  }

  @override
  Future<void> addToCart(String variantId, int quantity) async {
    if (mutationFails) throw const ShoppingException('Not enough stock.');
    final rows = carts[identity!.id] ??= [];
    final index = rows.indexWhere((line) => line.variantId == variantId);
    final variant = tee.variants.firstWhere(
      (variant) => variant.id == variantId,
    );
    final old = index < 0 ? null : rows.removeAt(index);
    rows.add(
      CartLine(
        id: old?.id ?? 'line-$variantId',
        variantId: variantId,
        quantity: (old?.quantity ?? 0) + quantity,
        revision: (old?.revision ?? 0) + 1,
        product: tee,
        variant: variant,
      ),
    );
  }

  @override
  Future<void> updateCartQuantity(CartLine line, int quantity) async {
    final rows = carts[identity!.id]!;
    final index = rows.indexWhere((row) => row.id == line.id);
    rows[index] = CartLine(
      id: line.id,
      variantId: line.variantId,
      quantity: quantity,
      revision: line.revision + 1,
      product: line.product,
      variant: line.variant,
    );
  }

  @override
  Future<void> removeCartLine(CartLine line) async {
    carts[identity!.id]!.removeWhere((row) => row.id == line.id);
  }

  @override
  Future<List<DeliveryAddress>> loadAddresses() async =>
      List.of(addresses[identity?.id] ?? []);
  @override
  Future<void> saveAddress(DeliveryAddress address) async {
    addressSaves++;
    final rows = addresses[identity!.id] ??= [];
    rows.removeWhere((row) => row.id == address.id);
    rows.add(
      DeliveryAddress.fromJson({
        'id': address.id ?? 'address-$addressSaves',
        ...address.toFields(),
        'is_default': false,
      }),
    );
  }

  @override
  Future<void> deleteAddress(String id) async {
    addresses[identity!.id]!.removeWhere((row) => row.id == id);
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    final rows = addresses[identity!.id]!;
    addresses[identity!.id] = rows
        .map(
          (row) => DeliveryAddress.fromJson({
            'id': row.id,
            ...row.toFields(),
            'is_default': row.id == id,
          }),
        )
        .toList();
  }
}

Future<void> showShop(WidgetTester tester, FakeShop shop) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MyApp(gateway: shop));
}

void main() {
  late FakeShop shop;
  setUp(() => shop = FakeShop());
  tearDown(() => shop.events.close());

  test(
    'Late cart response cannot restore the previous account after logout',
    () async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      final pending = Completer<List<CartLine>>();
      shop.delayedCart = pending.future;
      final cart = CartController(shop);
      addTearDown(cart.dispose);
      await shop.signOut();
      await Future<void>.delayed(Duration.zero);
      pending.complete([
        CartLine(
          id: 'old',
          variantId: 'm',
          quantity: 2,
          revision: 1,
          product: tee,
          variant: tee.variants.first,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(cart.lines, isEmpty);
      expect(cart.count, 0);
    },
  );

  test(
    'Rejected add releases the busy state and preserves the existing cart',
    () async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      final cart = CartController(shop);
      addTearDown(cart.dispose);
      await cart.refresh();
      await cart.add('m', 2);
      shop.mutationFails = true;
      await expectLater(cart.add('m', 1), throwsA(isA<ShoppingException>()));
      expect(cart.busy, isFalse);
      expect(cart.count, 2);
    },
  );

  testWidgets(
    'Add to cart merges quantities and cart changes persist after reopening',
    (tester) async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      await showShop(tester, shop);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive Tee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('M'));
      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();
      expect(shop.carts['admin']!.single.quantity, 2);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();
      expect(find.text('Selected subtotal (1)'), findsOneWidget);
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();
      expect(shop.carts['admin']!.single.quantity, 3);
      // Dispose the shell to simulate a fresh cart controller/session restore.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MyApp(gateway: shop));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.semanticsLabel == 'Quantity 3',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(shop.carts['admin'], isEmpty);
      expect(
        find.text('Your cart is empty. Explore the collection.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Address validation blocks incomplete fields, then saves usable fields',
    (tester) async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AddressEditor(gateway: shop, owner: 'admin'),
                  ),
                ),
                child: const Text('Open address editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open address editor'));
      await tester.pumpAndSettle();
      final save = find.text('Save address');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(shop.addressSaves, 0);
      final values = [
        'Demo recipient',
        '09123456789',
        'Metro Manila',
        'Quezon City',
        'Sample Barangay',
        '12 Demo Street',
        '1100',
        'Gate beside the shop',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.enterText(find.byType(TextFormField).at(i), values[i]);
      }
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(shop.addressSaves, 1);
      final address = shop.addresses['admin']!.single;
      expect(address.postalCode, '1100');
      expect(address.isDefault, isFalse);
      expect(address.toFields().containsKey('is_default'), isFalse);
    },
  );

  test('Peso display preserves centavos', () {
    expect(formatPesos(1200000), '₱12,000.00');
    expect(formatPesos(105), '₱1.05');
    expect(formatPesos(0), '₱0.00');
  });

  testWidgets('Public catalog filters and disables sold-out variant', (
    tester,
  ) async {
    await showShop(tester, shop);
    await tester.pumpAndSettle();
    expect(find.text('Archive Tee'), findsOneWidget);
    expect(find.text('Silver Band'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'archive');
    await tester.pumpAndSettle();
    expect(find.text('Silver Band'), findsNothing);
    await tester.tap(find.text('Archive Tee'));
    await tester.pumpAndSettle();
    final soldOut = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'XL · Sold out'),
    );
    expect(soldOut.onSelected, isNull);
    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();
    expect(find.text('6 available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Catalog fetch failure can be retried', (tester) async {
    shop.catalogFails = true;
    await showShop(tester, shop);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load the collection.'), findsOneWidget);
    shop.catalogFails = false;
    await tester.tap(find.text('Retry catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Archive Tee'), findsOneWidget);
  });

  testWidgets('Login validation, role display, and logout clear identity', (
    tester,
  ) async {
    await showShop(tester, shop);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in / Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(shop.signInCalls, 0);
    expect(find.text('Enter a valid email.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'owner@example.com');
    await tester.enterText(fields.at(1), 'demo-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(shop.signInCalls, 1);
    expect(find.text('Admin account'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Admin account'), findsNothing);
    expect(find.text('owner@example.com'), findsNothing);
    expect(find.text('Sign in / Register'), findsOneWidget);
    // A different customer must not inherit the previous account's admin display.
    shop.identity = const ShopIdentity('customer', 'customer@example.com');
    shop.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Customer account'), findsOneWidget);
    expect(find.text('Admin account'), findsNothing);
  });

  testWidgets('Signup without a session asks for email confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: AuthScreen(gateway: shop)));
    await tester.tap(find.text('New here? Create account'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Demo customer');
    await tester.enterText(fields.at(1), 'demo@example.com');
    await tester.enterText(fields.at(2), 'demo-password');
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(shop.signUpCalls, 1);
    expect(shop.currentUser, isNull);
    expect(
      find.text('Check your email to confirm your account, then sign in here.'),
      findsOneWidget,
    );
  });
}
