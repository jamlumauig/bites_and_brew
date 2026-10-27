import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/state/demo_session_manager.dart';
import 'package:cafe_and_brews/src/ui/screens/firebase_sign_in_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DemoSessionManager Tests', () {
    test('enters and exits demo mode updating SharedPreferences and notifying listeners', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final manager = DemoSessionManager.instance;
      await manager.init();
      expect(manager.isDemoMode, isFalse);

      var notified = false;
      manager.addListener(() {
        notified = true;
      });

      await manager.enterDemoMode();
      expect(manager.isDemoMode, isTrue);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('haven_is_demo_session_active'), isTrue);

      notified = false;
      await manager.exitDemoMode();
      expect(manager.isDemoMode, isFalse);
      expect(notified, isTrue);
      expect(prefs.getBool('haven_is_demo_session_active'), isFalse);
    });
  });

  group('CoffeePosController Demo Isolation Tests', () {
    test('demo controller initializes with demo bootstrap and admin role', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final demoRepo = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(
        repository: demoRepo,
        isDemo: true,
      );
      await controller.initialize();

      expect(controller.isDemo, isTrue);
      expect(controller.role, Role.admin);

      // Verify rich demo data is populated
      expect(controller.categories, isNotEmpty);
      expect(controller.products, isNotEmpty);
      expect(controller.modifierGroups, isNotEmpty);
      expect(controller.inventoryHealth, isNotEmpty);
      expect(controller.recentOrders, isNotEmpty);
      expect(controller.todaySales, greaterThan(0));

      final prefs = await SharedPreferences.getInstance();
      // Ensure NO production keys are populated
      expect(prefs.containsKey('bites_brew_reset_snapshot'), isFalse);
      expect(prefs.containsKey('coffee_pos_state_v1'), isFalse);

      // Verify any saved keys start with demo_storage_
      for (final key in prefs.getKeys()) {
        expect(key.startsWith('demo_storage_'), isTrue,
            reason: 'All demo persisted keys must start with demo_storage_');
      }
    });

    test('resetDemoData restores sample data without affecting production', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final controller = CoffeePosController(
        repository: InMemoryCoffeePosRepository(),
        isDemo: true,
      );
      await controller.initialize();

      final originalProductCount = controller.products.length;
      final originalFirstProduct = controller.products.first;

      // Mutate demo product
      controller.updateProduct(
        productId: originalFirstProduct.id,
        name: 'Modified Demo Drink',
        categoryId: originalFirstProduct.categoryId,
        price: 999.0,
        description: 'New Description',
        badge: 'NEW',
      );
      expect(controller.products.first.name, 'Modified Demo Drink');

      // Reset demo data
      await controller.resetDemoData();

      expect(controller.products.length, originalProductCount);
      expect(controller.products.first.name, originalFirstProduct.name);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('bites_brew_reset_snapshot'), isFalse);
      for (final key in prefs.getKeys()) {
        expect(key.startsWith('demo_storage_'), isTrue);
      }
    });

    test('production controller and demo controller are strictly isolated', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      // 1. Initialize production controller
      final prodRepo = InMemoryCoffeePosRepository();
      final prodController = CoffeePosController(
        repository: prodRepo,
        isDemo: false,
      );
      await prodController.initialize();
      final prodProductCount = prodController.products.length;

      // 2. Initialize demo controller
      final demoRepo = InMemoryCoffeePosRepository();
      final demoController = CoffeePosController(
        repository: demoRepo,
        isDemo: true,
      );
      await demoController.initialize();

      // 3. Mutate demo controller
      final initialDemoCount = demoController.products.length;
      demoController.deleteProduct(demoController.products.first.id);
      expect(demoController.products.length, initialDemoCount - 1);

      // 4. Verify production controller is unaffected
      expect(prodController.products.length, prodProductCount);
    });

    testWidgets('entering demo or demo2 directly signs into demo admin mode', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await DemoSessionManager.instance.exitDemoMode();
      expect(DemoSessionManager.instance.isDemoMode, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: FirebaseSignInScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter "demo2" as email and "demo2" as password
      final emailFields = find.byType(TextFormField);
      expect(emailFields, findsNWidgets(2));

      await tester.enterText(emailFields.at(0), 'demo2');
      await tester.enterText(emailFields.at(1), 'demo2');
      await tester.pump();

      // Tap Sign in
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(DemoSessionManager.instance.isDemoMode, isTrue);
    });
  });
}
