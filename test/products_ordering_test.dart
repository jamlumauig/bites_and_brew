import 'dart:convert';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/cashier_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CoffeePosController orderingController({bool many = false}) {
  final controller = CoffeePosController(
    repository: InMemoryCoffeePosRepository(),
  );
  controller.importStateJson(
    jsonEncode({
      'categories': [
        for (var i = 0; i < (many ? 30 : 2); i++)
          {
            'id': 'cat-$i',
            'name': i == 0
                ? 'Uploaded category with a very long name'
                : 'Category $i',
            'icon': '',
          },
      ],
      'products': [
        for (var i = 0; i < (many ? 80 : 5); i++)
          Product(
            id: 'p-$i',
            name: i == 0
                ? 'Uploaded product with a particularly long name'
                : 'Uploaded item $i',
            categoryId:
                'cat-${i < 4
                    ? 0
                    : many
                    ? i % 30
                    : 1}',
            price: 125.25 + i,
            description:
                'Description from the uploaded menu, including ingredients and other details.',
            badge: '',
            modifierGroupIds: i == 1 ? ['uploaded-options'] : [],
            useCategoryDefaults: false,
            isAvailable: i != 3,
          ).toJson(),
      ],
      'modifierGroups': [
        const ModifierGroup(
          id: 'uploaded-options',
          name: 'Uploaded size',
          minSelected: 1,
          maxSelected: 1,
          options: [
            ModifierOption(id: 'small', name: 'Small', priceDelta: 0),
            ModifierOption(id: 'large', name: 'Large', priceDelta: 25),
          ],
        ).toJson(),
      ],
    }),
  );
  return controller;
}

Future<void> showOrdering(
  WidgetTester tester,
  CoffeePosController controller,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: CashierDashboard(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(768, 700),
    const Size(1024, 700),
    const Size(1440, 900),
    const Size(1920, 1080),
  ]) {
    testWidgets('responsive ordering renders at $size', (tester) async {
      final controller = orderingController(many: true);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showOrdering(tester, controller, size);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('category-rail')), findsOneWidget);
      expect(
        find.byKey(
          ValueKey(size.width >= 900 ? 'current-order' : 'sticky-order-bar'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('add-p-0')));
      await tester.pumpAndSettle();
      expect(controller.cart.single.quantity, 1);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byTooltip(
          'Increase Uploaded product with a particularly long name',
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.cart.single.quantity, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'search spans categories, switches instantly, and follows replacement menus',
    (tester) async {
      final controller = orderingController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showOrdering(tester, controller, const Size(1200, 800));
      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'Uploaded item 4',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-p-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-p-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('category-cat-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-p-0')), findsOneWidget);
      controller.replaceProducts([
        const Product(
          id: 'replacement',
          name: 'Replacement menu item',
          categoryId: 'cat-1',
          price: 765.43,
          description: '',
          badge: '',
          modifierGroupIds: [],
          useCategoryDefaults: false,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Replacement menu item'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-p-0')), findsNothing);
      expect(find.byKey(const ValueKey('category-cat-0')), findsNothing);
    },
  );

  testWidgets(
    'variants are chosen before adding and aggregate quantities do not change an arbitrary line',
    (tester) async {
      final controller = orderingController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showOrdering(tester, controller, const Size(1200, 800));
      await tester.tap(find.byKey(const ValueKey('add-p-1')));
      await tester.pumpAndSettle();
      expect(controller.cart, isEmpty);
      expect(find.text('Uploaded size'), findsOneWidget);
      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();
      expect(controller.cart.single.quantity, 1);
      final product = controller.productById('p-1')!;
      controller.addProductToCart(
        product,
        selectedModifiers: [
          const SelectedModifier(
            groupId: 'uploaded-options',
            optionId: 'large',
            label: 'Large',
            priceDelta: 25,
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Decrease Uploaded item 1'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Uploaded item 1 to change'), findsOneWidget);
      expect(controller.cart.length, 2);
      expect(controller.cart.every((item) => item.quantity == 1), isTrue);
    },
  );

  testWidgets(
    'unavailable products cannot be added and phone order sheet updates live',
    (tester) async {
      final controller = orderingController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showOrdering(tester, controller, const Size(390, 844));
      final unavailable = tester.widget<FilledButton>(
        find.byKey(const ValueKey('add-p-3')),
      );
      expect(unavailable.onPressed, isNull);
      controller.addProductToCart(controller.productById('p-3')!);
      expect(controller.cart, isEmpty);
      await tester.tap(find.byKey(const ValueKey('add-p-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Order / Checkout'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(
          'Increase Uploaded product with a particularly long name in order',
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.cart.single.quantity, 2);
      await tester.tap(find.text('Proceed to Checkout'));
      await tester.pumpAndSettle();
      expect(find.text('Checkout'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty menu has an intentional state', (tester) async {
    final controller = orderingController();
    controller.replaceProducts([]);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showOrdering(tester, controller, const Size(390, 844));
    expect(find.text('No products yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
