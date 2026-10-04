import 'dart:convert';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/cashier_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CoffeePosController createController() {
  final controller = CoffeePosController(
    repository: InMemoryCoffeePosRepository(),
  );
  controller.importStateJson(
    jsonEncode({
      'categories': [
        for (var c = 0; c < 20; c++)
          Category(id: 'c$c', name: 'Category ${c + 1}', icon: '').toJson(),
      ],
      'products': [
        for (var c = 0; c < 20; c++)
          for (var p = 0; p < (c == 5 ? 40 : 1); p++)
            Product(
              id: 'p$c-$p',
              name: 'Product $c / $p',
              categoryId: 'c$c',
              price: 50,
              description: 'Uploaded description',
              badge: '',
              modifierGroupIds: ['options'],
              useCategoryDefaults: false,
            ).toJson(),
      ],
      'modifierGroups': [
        const ModifierGroup(
          id: 'options',
          name: 'Choose a variant',
          options: [
            ModifierOption(id: 'one', name: 'Option one', priceDelta: 0),
            ModifierOption(id: 'two', name: 'Option two', priceDelta: 10),
          ],
          minSelected: 1,
          maxSelected: 1,
        ).toJson(),
      ],
    }),
  );
  controller.selectCategory(5);
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'snapshot, cart changes, checkout and catalog reordering preserve category until a successful charge',
    () async {
      final controller = createController();
      addTearDown(controller.dispose);
      controller.productsScrollOffset = 420;
      controller.categoriesScrollOffset = 140;
      controller.addProductToCart(controller.visibleProducts.first);
      expect(controller.selectedCategory!.id, 'c5');
      expect(controller.cart, isNotEmpty);
      controller.importStateJson(controller.exportStateJson());
      expect(controller.selectedCategory!.id, 'c5');
      controller.replaceProducts(
        controller.products,
        categories: controller.categories.reversed.toList(),
      );
      expect(controller.selectedCategory!.id, 'c5');
      controller.setCartItemQuantity(controller.cart.single.lineId!, 3);
      expect(controller.selectedCategory!.id, 'c5');
      controller.updatePaymentType(PaymentType.cash);
      expect(await controller.checkout(), isNull);
      expect(controller.selectedCategory!.id, 'c5');
      expect(controller.productsScrollOffset, 420);
      controller.updatePaymentType(PaymentType.card);
      final order = await controller.checkout();
      expect(order, isNotNull);
      expect(controller.cart, isEmpty);
      expect(
        controller.selectedCategory!.id,
        controller.cashierCategories.first.id,
      );
      expect(controller.productsScrollOffset, 0);
      expect(controller.categoriesScrollOffset, 0);
    },
  );

  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    testWidgets(
      'category 6 and both scroll offsets survive active-order interactions at $size',
      (tester) async {
        final controller = createController();
        addTearDown(controller.dispose);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget screen() => MaterialApp(
          home: Scaffold(body: CashierDashboard(controller: controller)),
        );
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        final products = find.byKey(
          ValueKey(size.width < 600 ? 'mobile-products' : 'desktop-products'),
        );
        await tester.drag(products, const Offset(0, -430));
        await tester.drag(
          find.byKey(const ValueKey('category-rail')),
          const Offset(0, -170),
        );
        await tester.pumpAndSettle();
        final productOffset = controller.productsScrollOffset;
        final categoryOffset = controller.categoriesScrollOffset;
        expect(productOffset, greaterThan(0));
        expect(categoryOffset, greaterThan(0));
        void expectPreserved() {
          expect(controller.selectedCategory!.id, 'c5');
          expect(controller.productsScrollOffset, closeTo(productOffset, .01));
          expect(
            controller.categoriesScrollOffset,
            closeTo(categoryOffset, .01),
          );
          expect(tester.takeException(), isNull);
        }

        final addButton = find
            .byWidgetPredicate(
              (widget) =>
                  widget is FilledButton &&
                  widget.key is ValueKey<String> &&
                  (widget.key as ValueKey<String>).value.startsWith('add-'),
            )
            .hitTestable()
            .first;
        await tester.tap(addButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Option two +₱10.00'));
        await tester.tap(find.text('Add to cart'));
        await tester.pumpAndSettle();
        expectPreserved();
        controller.setCartItemQuantity(controller.cart.single.lineId!, 3);
        await tester.pumpAndSettle();
        expectPreserved();
        if (size.width < 900) {
          await tester.tap(find.text('View Order / Checkout'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Proceed to Checkout'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back to order'));
        await tester.pumpAndSettle();
        if (size.width < 900) {
          Navigator.of(
            tester.element(find.byKey(const ValueKey('current-order'))),
          ).pop();
          await tester.pumpAndSettle();
        }
        expectPreserved();
        // Realtime account writes take the same snapshot-application path.
        controller.importStateJson(controller.exportStateJson());
        await tester.pumpAndSettle();
        expectPreserved();
        // Recreating the Products widget (e.g. returning from another section)
        // restores device-local navigation rather than treating it as a new order.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        expectPreserved();
        controller.removeCartItem(controller.cart.single.lineId!);
        await tester.pumpAndSettle();
        expectPreserved();
        controller.clearCart();
        await tester.pumpAndSettle();
        expectPreserved();
        controller.addProductToCart(controller.visibleProducts.first);
        controller.updatePrinterSettings(
          printerName: 'Test',
          printerUrl: '',
          autoPrintReceipts: false,
        );
        await tester.pumpAndSettle();
        if (size.width < 900) {
          await tester.tap(find.text('View Order / Checkout'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Proceed to Checkout'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Charge '));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('New Order'), findsNothing);
        expect(controller.selectedCategory!.id, 'c0');
        expect(controller.productsScrollOffset, 0);
        expect(controller.categoriesScrollOffset, 0);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
      },
    );
  }
}
