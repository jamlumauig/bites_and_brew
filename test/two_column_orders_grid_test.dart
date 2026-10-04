import 'dart:convert';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/coffee_pos_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CoffeePosController createPopulatedController() {
    final sample = StoreBootstrap.sample();
    final repository = InMemoryCoffeePosRepository();
    final controller = CoffeePosController(repository: repository);
    final now = DateTime.now();

    final activeOrders = [
      OrderQueueRecord(
        id: 'active-1',
        sequence: 1,
        orderNumber: '20261003-001',
        status: OrderQueueStatus.preparing,
        customerName: 'Walk-in Guest 1',
        orderType: 'Dine-in',
        createdAt: now,
        items: [
          const OrderLineSnapshot(
            lineId: 'line-1',
            productId: 'latte',
            productName: 'Caramel Cloud Latte',
            unitPrice: 145,
            quantity: 1,
            modifierLabels: ['16 oz', 'Regular Milk'],
            lineTotal: 145,
          ),
        ],
      ),
      OrderQueueRecord(
        id: 'active-2',
        sequence: 2,
        orderNumber: '20261003-002',
        status: OrderQueueStatus.pending,
        customerName: 'Walk-in Guest 2',
        orderType: 'Takeout',
        createdAt: now,
        items: [
          const OrderLineSnapshot(
            lineId: 'line-2',
            productId: 'matcha',
            productName: 'Matcha Cloud',
            unitPrice: 162,
            quantity: 2,
            modifierLabels: ['16 oz'],
            lineTotal: 324,
          ),
        ],
      ),
    ];

    final recentOrders = [
      OrderRecord(
        id: 'order-1',
        sequence: 1,
        orderNumber: '20261003-001',
        status: OrderStatus.paid,
        orderType: 'Dine-in',
        paymentType: PaymentType.cash,
        cashierName: 'Barista',
        createdAt: now,
        subtotal: 145,
        discount: 0,
        tax: 0,
        serviceCharge: 0,
        total: 145,
        cashReceived: 200,
        change: 55,
        items: const [
          OrderLineSnapshot(
            lineId: 'line-1',
            productId: 'latte',
            productName: 'Caramel Cloud Latte',
            unitPrice: 145,
            quantity: 1,
            modifierLabels: ['16 oz'],
            lineTotal: 145,
          ),
        ],
      ),
      OrderRecord(
        id: 'order-2',
        sequence: 2,
        orderNumber: '20261003-002',
        status: OrderStatus.paid,
        orderType: 'Takeout',
        paymentType: PaymentType.eWallet,
        cashierName: 'Barista',
        createdAt: now,
        subtotal: 324,
        discount: 0,
        tax: 0,
        serviceCharge: 0,
        total: 324,
        cashReceived: 324,
        change: 0,
        items: const [
          OrderLineSnapshot(
            lineId: 'line-2',
            productId: 'matcha',
            productName: 'Matcha Cloud',
            unitPrice: 162,
            quantity: 2,
            modifierLabels: ['16 oz'],
            lineTotal: 324,
          ),
        ],
      ),
    ];

    final bootstrap = StoreBootstrap(
      categories: sample.categories,
      products: sample.products,
      modifierGroups: sample.modifierGroups,
      inventoryHealth: const [],
      todaySales: 469.0,
      recentOrders: recentOrders,
      activeShifts: const [],
      activeOrders: activeOrders,
      customers: const [],
    );

    controller.importStateJson(jsonEncode(bootstrap.toJson()));
    return controller;
  }

  group('2-Column Grid Layout for In Progress and Orders', () {
    testWidgets(
        'In Progress and Orders display exactly 2 columns on mobile viewport with no overflows',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createPopulatedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoffeePosShell(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigate to In Progress via drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('In Progress').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify In Progress header is visible
      expect(find.text('In Progress Orders'), findsOneWidget);

      // Verify GridView with crossAxisCount: 2 is used
      final inProgressGrids = find.byType(GridView);
      expect(inProgressGrids, findsWidgets);
      final gridWidget = tester.widget<GridView>(inProgressGrids.first);
      final delegate =
          gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);

      // Verify cards are rendered
      expect(find.textContaining('Walk-in'), findsWidgets);
      // No RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Now navigate to Orders / Order History via drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Orders').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Orders header
      expect(find.text('Orders / Order History'), findsOneWidget);

      // Verify GridView with crossAxisCount: 2 is used
      final historyGridWidget =
          tester.widget<GridView>(find.byType(GridView).first);
      final historyDelegate = historyGridWidget.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(historyDelegate.crossAxisCount, 2);

      // Verify order history cards rendered
      expect(find.textContaining('Order #'), findsWidgets);
      expect(find.text('Print'), findsWidgets);

      // Verify no exceptions or overflows on mobile
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'In Progress and Orders display responsive compact columns on desktop/web viewport with no overflows',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createPopulatedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoffeePosShell(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigate to In Progress via permanent sidebar
      await tester.tap(find.text('In Progress').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('In Progress Orders'), findsOneWidget);
      final gridWidget = tester.widget<GridView>(find.byType(GridView).first);
      final delegate =
          gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4);
      expect(find.textContaining('Walk-in'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Navigate to Orders
      await tester.tap(find.text('Orders').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Orders / Order History'), findsOneWidget);
      final historyGridWidget =
          tester.widget<GridView>(find.byType(GridView).first);
      final historyDelegate = historyGridWidget.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(historyDelegate.crossAxisCount, 4);
      expect(find.text('Print receipt'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
