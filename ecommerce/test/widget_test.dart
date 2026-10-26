import 'dart:async';
import 'dart:typed_data';

import 'package:ecommerce/app.dart';
import 'package:ecommerce/models/catalog.dart';
import 'package:ecommerce/models/shopping.dart';
import 'package:ecommerce/models/checkout.dart';
import 'package:ecommerce/models/order.dart';
import 'package:ecommerce/models/admin.dart';
import 'package:ecommerce/services/admin_gateway.dart';
import 'package:ecommerce/screens/admin/admin_guard.dart';
import 'package:ecommerce/screens/admin/admin_screen.dart';
import 'package:ecommerce/screens/admin/admin_orders_screen.dart';
import 'package:ecommerce/screens/admin/admin_forms.dart';
import 'package:ecommerce/services/order_placement.dart';
import 'package:ecommerce/screens/orders_screen.dart';
import 'package:ecommerce/screens/checkout_screen.dart';
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

const demoAddress = DeliveryAddress(
  id: 'address-1',
  recipient: 'Demo recipient',
  phone: '09123456789',
  province: 'Metro Manila',
  city: 'Quezon City',
  barangay: 'Sample',
  street: '12 Demo Street',
  postalCode: '1100',
  isDefault: true,
);

ShopOrder demoOrder(
  String key, {
  String status = 'pending',
  String state = 'active',
}) => ShopOrder(
  id: 'order-$key',
  ownerId: 'admin',
  number: 'BMC-DEMO',
  checkoutKey: key,
  paymentStatus: status,
  fulfillmentStatus: status == 'paid' ? 'preparing' : 'unfulfilled',
  paymentState: state,
  subtotalMinor: 1200000,
  shippingMinor: 15000,
  totalMinor: 1215000,
  createdAt: DateTime(2026, 10, 26),
  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
  address: demoAddress,
  items: const [
    QuotedItem(
      name: 'Archive Tee',
      option: 'M',
      quantity: 1,
      unitPriceMinor: 1200000,
      lineTotalMinor: 1200000,
    ),
  ],
  paymentUrl: state == 'active'
      ? 'https://checkout-staging.xendit.co/test-payment'
      : null,
);

class FakeShop extends ShopGateway {
  AdminGateway? adminService;
  @override
  AdminGateway get admin => adminService ?? super.admin;
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
  CheckoutSelection? lastQuoteSelection;
  final attempts = <String, CheckoutAttempt>{};
  final orders = <String, List<ShopOrder>>{};
  int paymentRequests = 0;
  Object? paymentError;
  bool createBeforeError = false;
  bool cacheFails = false;
  Completer<void>? paymentWait;
  final requestedKeys = <String>[];
  @override
  ShopIdentity? get currentUser => identity;
  @override
  Stream<void> get authChanges => events.stream;

  @override
  Future<CheckoutAttempt?> loadCheckoutAttempt() async =>
      attempts[identity!.id];
  @override
  Future<void> saveCheckoutAttempt(CheckoutAttempt attempt) async {
    if (cacheFails) throw StateError('Local storage unavailable');
    attempts[identity!.id] = attempt;
  }

  @override
  Future<void> clearCheckoutAttempt(String expectedKey) async {
    if (attempts[identity!.id]?.key == expectedKey) {
      attempts.remove(identity!.id);
    }
  }

  @override
  Future<ShopOrder?> findOrderByCheckoutKey(String key) async =>
      (orders[identity!.id] ?? [])
          .where((order) => order.checkoutKey == key)
          .firstOrNull;
  @override
  Future<ShopOrder> loadOrder(String id) async =>
      orders[identity!.id]!.firstWhere((order) => order.id == id);
  @override
  Future<List<ShopOrder>> loadOrders() async =>
      List.of(orders[identity!.id] ?? []);
  @override
  Future<void> requestPayment(CheckoutAttempt attempt) async {
    final owner = identity!.id;
    paymentRequests++;
    requestedKeys.add(attempt.key);
    await paymentWait?.future;
    if (paymentError == null || createBeforeError) {
      (orders[owner] ??= []).add(demoOrder(attempt.key));
    }
    if (paymentError != null) throw paymentError!;
  }

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

  @override
  Future<CheckoutQuote> quoteCheckout(
    CheckoutSelection selection,
    String addressId,
  ) async {
    lastQuoteSelection = selection;
    return CheckoutQuote(
      subtotalMinor: 1200000,
      shippingMinor: 15000,
      totalMinor: 1215000,
      address: addresses[identity!.id]!.firstWhere(
        (row) => row.id == addressId,
      ),
      items: const [
        QuotedItem(
          name: 'Archive Tee',
          option: 'M',
          quantity: 1,
          unitPriceMinor: 1200000,
          lineTotalMinor: 1200000,
        ),
      ],
    );
  }
}

Future<void> showShop(WidgetTester tester, FakeShop shop) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MyApp(gateway: shop));
}

class FakeAdmin implements AdminGateway {
  int statsCalls = 0;
  ShopOrder? order;
  final updates = <String>[];
  final savedProducts = <AdminProduct>[];
  final photoProductIds = <String>[];
  bool photoFails = false;
  @override
  Future<AdminStats> loadStats() async {
    statsCalls++;
    return const AdminStats(0, 1, 1, 0);
  }

  @override
  Future<AdminCatalog> loadCatalog() async =>
      const AdminCatalog(categories: [], products: [], variants: []);
  @override
  Future<List<ShopOrder>> loadOrders({
    required int offset,
    String? paymentStatus,
  }) async => order == null ? [] : [order!];
  @override
  Future<ShopOrder> loadOrder(String id) async => order!;
  @override
  Future<void> updateFulfillment(String id, String status) async {
    final previous = order!;
    if (nextFulfillment(previous.paymentStatus, previous.fulfillmentStatus) !=
        status) {
      throw const ShoppingException('Invalid transition');
    }
    updates.add(status);
    order = ShopOrder(
      id: previous.id,
      ownerId: previous.ownerId,
      number: previous.number,
      checkoutKey: previous.checkoutKey,
      paymentStatus: previous.paymentStatus,
      fulfillmentStatus: status,
      paymentState: previous.paymentState,
      subtotalMinor: previous.subtotalMinor,
      shippingMinor: previous.shippingMinor,
      totalMinor: previous.totalMinor,
      createdAt: previous.createdAt,
      expiresAt: previous.expiresAt,
      address: previous.address,
      items: previous.items,
    );
  }

  @override
  Future<void> saveCategory(AdminCategory category) async {}
  @override
  Future<void> saveProduct(AdminProduct product) async {
    savedProducts.add(product);
  }

  @override
  Future<void> saveVariant(AdminVariant variant) async {}
  @override
  Future<void> uploadImage(
    String productId,
    UploadImage image,
    int sortOrder, {
    AdminImage? replacing,
  }) async {
    photoProductIds.add(productId);
    if (photoFails) throw StateError('Upload unavailable');
  }
}

void main() {
  late FakeShop shop;
  setUp(() => shop = FakeShop());
  tearDown(() => shop.events.close());

  testWidgets(
    'Product photo selection saves metadata before upload and keeps the saved product on upload failure',
    (tester) async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      tester.view.physicalSize = const Size(800, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const catalog = AdminCatalog(
        categories: [
          AdminCategory(
            id: 'category',
            name: 'Demo',
            slug: 'demo',
            active: true,
            sortOrder: 0,
          ),
        ],
        products: [],
        variants: [],
      );
      for (final fails in [false, true]) {
        final admin = FakeAdmin()..photoFails = fails;
        shop.adminService = admin;
        String? savedId;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(fails),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    savedId = await Navigator.of(context).push<String>(
                      MaterialPageRoute<String>(
                        builder: (_) => AdminProductForm(
                          shop: shop,
                          catalog: catalog,
                          pickImage: () async => UploadImage.validate(
                            Uint8List.fromList([
                              137,
                              80,
                              78,
                              71,
                              13,
                              10,
                              26,
                              10,
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open product form'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open product form'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose photo'));
        await tester.pumpAndSettle();
        expect(admin.savedProducts, isEmpty);
        expect(admin.photoProductIds, isEmpty);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Demo product',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'demo-product',
        );
        final save = find.widgetWithText(FilledButton, 'Save');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(admin.savedProducts.length, 1);
        expect(savedId, admin.savedProducts.single.id);
        expect(admin.photoProductIds, [savedId]);
        if (fails) {
          expect(
            find.textContaining(
              'Product saved, but photo upload was not confirmed',
            ),
            findsOneWidget,
          );
        }
      }
    },
  );

  testWidgets('Customer cannot open an admin page or load store stats', (
    tester,
  ) async {
    shop.identity = const ShopIdentity('customer', 'customer@example.com');
    final admin = FakeAdmin();
    shop.adminService = admin;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminGuard(
          shop: shop,
          builder: (_) => AdminScreen(shop: shop),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin access is required.'), findsOneWidget);
    expect(admin.statsCalls, 0);
  });

  testWidgets('Switching away from admin hides the privileged screen', (
    tester,
  ) async {
    shop.identity = const ShopIdentity('admin', 'owner@example.com');
    shop.adminService = FakeAdmin();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminGuard(
          shop: shop,
          builder: (_) => AdminScreen(shop: shop),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Store overview'), findsOneWidget);
    shop.identity = const ShopIdentity('customer', 'customer@example.com');
    shop.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Store overview'), findsNothing);
    expect(find.text('Admin access is required.'), findsOneWidget);
  });

  testWidgets(
    'Admin advances paid fulfillment without changing payment status',
    (tester) async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      final admin = FakeAdmin()
        ..order = demoOrder('fulfilled', status: 'paid', state: 'paid');
      shop.adminService = admin;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminOrderScreen(shop: shop, orderId: admin.order!.id),
        ),
      );
      await tester.pumpAndSettle();
      final ship = find.text('Mark as shipped');
      await tester.ensureVisible(ship);
      await tester.tap(ship);
      await tester.pumpAndSettle();
      final deliver = find.text('Mark as delivered');
      await tester.ensureVisible(deliver);
      await tester.tap(deliver);
      await tester.pumpAndSettle();
      expect(admin.updates, ['shipped', 'delivered']);
      expect(admin.order!.paymentStatus, 'paid');
      expect(find.text('This order has been delivered.'), findsOneWidget);
    },
  );

  CheckoutAttempt attempt(String key) => CheckoutAttempt(
    key: key,
    source: 'buy_now',
    addressId: 'address-1',
    items: CheckoutSelection.buyNow('m', 1).items,
  );

  test('Lost checkout response recovers the committed order without another provider request', () async {
    shop.identity = const ShopIdentity('admin', 'owner@example.com');
    shop.paymentError = TimeoutException('Response lost');
    shop.createBeforeError = true;
    final request = attempt('same-checkout');
    final order = await placeOrResumeOrder(shop, request);
    expect(order.paid, isFalse);
    expect(shop.paymentRequests, 1);
    expect(shop.attempts['admin'], isNull);
    await placeOrResumeOrder(shop, request);
    expect(shop.paymentRequests, 1);
  });

  test('Unconfirmed checkout retains its original key and blocks a different retry', () async {
    shop.identity = const ShopIdentity('admin', 'owner@example.com');
    shop.paymentError = TimeoutException('Network unavailable');
    final request = attempt('same-checkout');
    await expectLater(
      placeOrResumeOrder(shop, request),
      throwsA(isA<ShoppingException>()),
    );
    expect(shop.attempts['admin']!.key, request.key);
    await expectLater(
      placeOrResumeOrder(shop, attempt('different-checkout')),
      throwsA(isA<ShoppingException>()),
    );
    expect(shop.paymentRequests, 1);
    shop.paymentError = null;
    await placeOrResumeOrder(shop, request);
    expect(shop.requestedKeys, ['same-checkout', 'same-checkout']);
  });

  test('Local recovery-save failure prevents a payment request', () async {
    shop.identity = const ShopIdentity('admin', 'owner@example.com');
    shop.cacheFails = true;
    await expectLater(
      placeOrResumeOrder(shop, attempt('not-sent')),
      throwsStateError,
    );
    expect(shop.paymentRequests, 0);
  });

  test('Confirmed validation rejection without an order releases the editable draft', () async {
    shop.identity = const ShopIdentity('admin', 'owner@example.com');
    shop.paymentError = const PaymentRequestException(400, 'Not enough stock');
    await expectLater(
      placeOrResumeOrder(shop, attempt('rejected')),
      throwsA(isA<CheckoutRejected>()),
    );
    expect(shop.attempts['admin'], isNull);
    expect(shop.orders['admin'], isNull);
  });

  test(
    'Account change during placement cannot display the previous account order',
    () async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      shop.paymentWait = Completer<void>();
      final result = placeOrResumeOrder(shop, attempt('in-flight'));
      while (shop.paymentRequests == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      shop.identity = const ShopIdentity('customer', 'customer@example.com');
      final assertion = expectLater(result, throwsA(isA<ShoppingException>()));
      shop.paymentWait!.complete();
      await assertion;
      expect(shop.attempts['admin']!.key, 'in-flight');
      expect(shop.attempts['customer'], isNull);
    },
  );

  testWidgets('Rapid Place Order taps submit one checkout', (tester) async {
    shop.identity = const ShopIdentity('admin', 'owner@example.com');
    shop.addresses['admin'] = [demoAddress];
    shop.paymentWait = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(
          gateway: shop,
          selection: CheckoutSelection.buyNow('m', 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final place = find.text('Place Order');
    await tester.tap(place);
    await tester.tap(place);
    await tester.pump();
    expect(shop.paymentRequests, 1);
    shop.paymentWait!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pending payment'), findsOneWidget);
    expect(shop.orders['admin']!.length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('An initial order from a different account is hidden', (
    tester,
  ) async {
    shop.identity = const ShopIdentity('customer', 'customer@example.com');
    final oldOrder = demoOrder('owner-order');
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailsScreen(
          gateway: shop,
          orderId: oldOrder.id,
          initialOrder: oldOrder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account changed. Return to My orders.'), findsOneWidget);
    expect(find.text(demoAddress.phone), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Opening payment never marks paid; only a refreshed backend state does',
    (tester) async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      final order = demoOrder('existing');
      shop.orders['admin'] = [order];
      var opened = 0;
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailsScreen(
            gateway: shop,
            orderId: order.id,
            initialOrder: order,
            launchPayment: (_) async {
              opened++;
              return true;
            },
            previousTotalMinor: 1200000,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pay = find.text('Continue to Xendit');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.textContaining('Order total changed from'), findsOneWidget);
      expect(find.text('Pending payment'), findsOneWidget);
      expect(find.text('Paid'), findsNothing);
      shop.orders['admin'] = [
        demoOrder('existing', status: 'paid', state: 'paid'),
      ];
      await tester.tap(find.byTooltip('Refresh order status'));
      await tester.pumpAndSettle();
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Continue to Xendit'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Buy Now opens a server-priced review without changing the saved cart',
    (tester) async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      shop.addresses['admin'] = [demoAddress];
      shop.carts['admin'] = [
        CartLine(
          id: 'saved',
          variantId: 'm',
          quantity: 2,
          revision: 1,
          product: tee,
          variant: tee.variants.first,
        ),
      ];
      await showShop(tester, shop);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive Tee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('M'));
      await tester.tap(find.text('Buy Now'));
      await tester.pumpAndSettle();
      expect(find.text('Shipping'), findsOneWidget);
      expect(find.text('₱12,150.00'), findsOneWidget);
      expect(shop.lastQuoteSelection!.source, 'buy_now');
      expect(shop.lastQuoteSelection!.items.single, {
        'variant_id': 'm',
        'quantity': 1,
      });
      expect(shop.carts['admin']!.single.quantity, 2);
    },
  );

  testWidgets('Checkout without a saved address does not request a quote', (
    tester,
  ) async {
    shop.identity = const ShopIdentity('admin', 'owner@example.com');
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(
          gateway: shop,
          selection: CheckoutSelection.buyNow('m', 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Add a delivery address to review your order.'),
      findsOneWidget,
    );
    expect(find.text('Add / edit addresses'), findsOneWidget);
    expect(shop.lastQuoteSelection, isNull);
  });

  testWidgets(
    'Cart checkout sends only selected cart IDs and preserves unselected rows',
    (tester) async {
      shop.identity = const ShopIdentity('admin', 'owner@example.com');
      shop.addresses['admin'] = [demoAddress];
      shop.carts['admin'] = [
        CartLine(
          id: 'selected',
          variantId: 'm',
          quantity: 1,
          revision: 1,
          product: tee,
          variant: tee.variants.first,
        ),
        CartLine(
          id: 'unselected',
          variantId: '8',
          quantity: 1,
          revision: 1,
          product: ring,
          variant: ring.variants.first,
        ),
      ];
      await showShop(tester, shop);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Checkout'));
      await tester.pumpAndSettle();
      expect(shop.lastQuoteSelection!.source, 'cart');
      expect(shop.lastQuoteSelection!.items, [
        {'cart_item_id': 'selected'},
      ]);
      expect(shop.carts['admin']!.length, 2);
    },
  );

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
