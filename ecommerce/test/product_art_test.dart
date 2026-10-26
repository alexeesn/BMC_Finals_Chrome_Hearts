import 'package:ecommerce/models/catalog.dart';
import 'package:ecommerce/widgets/product_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const product = CatalogProduct(
  id: 'tee',
  name: 'Archive Tee',
  description: '',
  category: 'Clothing',
  variants: [],
);

void main() {
  for (final size in [
    const Size(64, 76),
    const Size(160, 160),
    const Size(320, 280),
  ]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('Image fallback fits $size with text scale $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox.fromSize(
                    size: size,
                    child: const ProductArt(product: product),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(ProductArt)), size);
        expect(
          find.text('IMAGE COMING SOON'),
          size.width < 120 ? findsNothing : findsOneWidget,
        );
        expect(find.byIcon(Icons.checkroom_outlined), findsOneWidget);
      });
    }
  }
}
