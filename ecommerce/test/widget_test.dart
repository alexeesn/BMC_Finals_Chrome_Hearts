import 'dart:async';

import 'package:ecommerce/app.dart';
import 'package:ecommerce/models/catalog.dart';
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
