import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'delete all data preserves products and persists the cleared state',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final repository = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repository);
      await controller.initialize();

      final originalProductIds = controller.products
          .map((product) => product.id)
          .toList(growable: false);
      final originalCategoryIds = controller.categories
          .map((category) => category.id)
          .toList(growable: false);
      final originalModifierGroupIds = controller.modifierGroups
          .map((group) => group.id)
          .toList(growable: false);

      expect(controller.recentOrders, isEmpty);
      expect(controller.activeOrders, isEmpty);
      expect(controller.activeShifts, isEmpty);
      expect(controller.inventoryHealth, isEmpty);

      await controller.deleteAllData();

      expect(
        controller.products
            .map((product) => product.id)
            .toList(growable: false),
        originalProductIds,
      );
      expect(
        controller.categories
            .map((category) => category.id)
            .toList(growable: false),
        originalCategoryIds,
      );
      expect(
        controller.modifierGroups
            .map((group) => group.id)
            .toList(growable: false),
        originalModifierGroupIds,
      );
      expect(controller.recentOrders, isEmpty);
      expect(controller.activeOrders, isEmpty);
      expect(controller.activeShifts, isEmpty);
      expect(controller.inventoryHealth, isEmpty);
      expect(controller.customers, isEmpty);
      expect(controller.todaySales, 0);
      expect(controller.cart, isEmpty);
      expect(controller.storeName, 'Haven & Co.');

      final reloaded = CoffeePosController(repository: repository);
      await reloaded.initialize();

      expect(
        reloaded.products.map((product) => product.id).toList(growable: false),
        originalProductIds,
      );
      expect(
        reloaded.categories
            .map((category) => category.id)
            .toList(growable: false),
        originalCategoryIds,
      );
      expect(
        reloaded.modifierGroups
            .map((group) => group.id)
            .toList(growable: false),
        originalModifierGroupIds,
      );
      expect(reloaded.recentOrders, isEmpty);
      expect(reloaded.activeOrders, isEmpty);
      expect(reloaded.activeShifts, isEmpty);
      expect(reloaded.inventoryHealth, isEmpty);
      expect(reloaded.customers, isEmpty);
      expect(reloaded.todaySales, 0);
      expect(reloaded.cart, isEmpty);
    },
  );

  test('completed orders are persisted with the account state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repository = InMemoryCoffeePosRepository();
    final controller = CoffeePosController(repository: repository);
    await controller.initialize();
    controller.addProductToCart(controller.products.first);

    final completedOrder = await controller.checkout();

    expect(completedOrder, isNotNull);
    expect(controller.recentOrders, hasLength(1));
    expect(controller.activeOrders, hasLength(1));

    final reloaded = CoffeePosController(repository: repository);
    await reloaded.initialize();

    expect(reloaded.recentOrders, hasLength(1));
    expect(reloaded.recentOrders.single.id, completedOrder!.id);
    expect(reloaded.activeOrders, hasLength(1));
    expect(reloaded.todaySales, completedOrder.total);
  });

  test('completing an active order works without a Firebase session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repository = InMemoryCoffeePosRepository();
    final controller = CoffeePosController(repository: repository);
    await controller.initialize();
    controller.addProductToCart(controller.products.first);
    await controller.checkout();

    final activeOrder = controller.activeOrders.single;
    final completed = await controller.completeOrder(activeOrder);

    expect(completed, isTrue);
    expect(controller.activeOrders, isEmpty);

    await controller.flushPersistence();

    final reloaded = CoffeePosController(repository: repository);
    await reloaded.initialize();
    expect(reloaded.activeOrders, isEmpty);
  });

  test('printer settings default to GEZHI_micro_printer, 80mm roll, and Direct print (no prompt)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repository = InMemoryCoffeePosRepository();
    final controller = CoffeePosController(repository: repository);
    await controller.initialize();

    expect(controller.printerName, 'GEZHI_micro_printer');
    expect(controller.thermalPaperWidth, 80);
    expect(controller.thermalTransport, 'Direct print (no prompt)');
    expect(controller.autoPrintReceipts, isTrue);
    expect(controller.thermalAutoCut, isTrue);
    expect(controller.thermalFeedLines, 2);
  });
}
