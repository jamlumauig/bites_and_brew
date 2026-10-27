import 'dart:convert';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CoffeePosController createTestController({
    List<OrderRecord>? orders,
    List<InventoryHealth>? inventory,
  }) {
    final sample = StoreBootstrap.sample();
    final repository = InMemoryCoffeePosRepository();
    final controller = CoffeePosController(repository: repository);
    final bootstrap = StoreBootstrap(
      categories: sample.categories,
      products: sample.products,
      modifierGroups: sample.modifierGroups,
      inventoryHealth: inventory ??
          const [
            InventoryHealth(
              id: 'inv-1',
              itemName: 'Arabica Coffee Beans',
              statusLabel: 'In Stock',
              onHand: 45,
              threshold: 15,
              severity: InventorySeverity.good,
            ),
          ],
      todaySales: 1500.0,
      recentOrders: orders ?? const [],
      activeShifts: const [],
      activeOrders: const [],
      customers: const [],
    );
    controller.importStateJson(jsonEncode(bootstrap.toJson()));
    return controller;
  }

  group('Admin Dashboard Redesign Tests', () {
    testWidgets('Desktop view renders sidebar with icon+label and Overview page components', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createTestController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Brand in sidebar
      expect(find.text('LUNAN'), findsOneWidget);
      expect(find.text('Back Office'), findsOneWidget);

      // Sidebar navigation items (with both icon and text)
      // Note: 'Overview' is in both sidebar and page header
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);

      // KPI cards in Overview
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Average Order'), findsOneWidget);
      expect(find.text('Low Stock Items'), findsOneWidget);

      // Sales Trend Card
      expect(find.text('Sales Trend'), findsOneWidget);

      // Bottom 2-column cards
      expect(find.text('Top Selling Products'), findsOneWidget);
      expect(find.text('Sales by Category'), findsOneWidget);
    });

    testWidgets('Navigation switches to Products, Inventory, and Orders tabs properly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createTestController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Click Products tab in sidebar
      await tester.tap(find.text('Products').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Products header and toolbar
      expect(find.text('Manage catalog items, pricing, and availability'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
      expect(find.text('Upload Menu'), findsOneWidget);
      expect(find.text('Download Menu'), findsOneWidget);
      expect(find.text('Search products...'), findsOneWidget);

      // 2. Click Inventory tab in sidebar
      await tester.tap(find.text('Inventory').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Inventory header and toolbar
      expect(find.text('Stock levels, reorder thresholds, and inventory health'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
      expect(find.text('Search inventory...'), findsOneWidget);

      // 3. Click Orders tab in sidebar
      await tester.tap(find.text('Orders').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Orders header and toolbar
      expect(find.text('Order history, activity logs, and customer receipts'), findsOneWidget);
      expect(find.text('Search order #, cashier...'), findsOneWidget);
    });

    testWidgets('Order Details dialog opens when View is clicked', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testOrder = OrderRecord(
        id: 'ord-101',
        sequence: 1,
        orderNumber: '20261003-001',
        status: OrderStatus.paid,
        orderType: 'Dine-in',
        paymentType: PaymentType.cash,
        cashierName: 'Maria',
        createdAt: DateTime.now(),
        subtotal: 120.0,
        discount: 0.0,
        tax: 14.4,
        serviceCharge: 0.0,
        total: 120.0,
        cashReceived: 200.0,
        change: 80.0,
        items: const [
          OrderLineSnapshot(
            lineId: 'line-1',
            productId: 'latte',
            productName: 'Caffe Latte',
            unitPrice: 120.0,
            quantity: 1,
            modifierLabels: ['Hot', 'Whole Milk'],
            lineTotal: 120.0,
          ),
        ],
        grossAmount: 120.0,
        vatableSales: 107.14,
        vatExemptSales: 0.0,
        vatExemptionAmount: 0.0,
        seniorDiscount: 0.0,
        pwdDiscount: 0.0,
        otherDiscount: 0.0,
        totalDiscount: 0.0,
        discountApplication: const DiscountApplication.none(),
      );

      final controller = createTestController(orders: [testOrder]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to Orders tab
      await tester.tap(find.text('Orders').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the 'View' button in the orders table
      final viewButton = find.text('View');
      expect(viewButton, findsWidgets);

      await tester.tap(viewButton.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the Dialog opened with full order breakdown
      expect(find.text('Order #${testOrder.orderNumber}'), findsOneWidget);
      expect(find.text('Ordered Items'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Close the dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Print Receipt'), findsNothing);
    });

    testWidgets('Mobile view renders vertical sidebar and avoids overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createTestController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Mobile nav chips and page title
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);

      // Switch tab on mobile
      await tester.tap(find.text('Products').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Manage catalog items, pricing, and availability'), findsOneWidget);
    });

    testWidgets('Customizations tab renders stacked responsive layout on mobile without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createTestController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Click Customizations tab in mobile sidebar
      await tester.tap(find.text('Customizations').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify header and page content
      expect(find.text('Dynamic modifier groups, add-ons, sizes, and menu options'), findsOneWidget);
      expect(find.text('Add Group'), findsWidgets);

      // Verify groups are present and not squashed
      expect(find.text('Drink size'), findsOneWidget);
      expect(find.text('Snack size'), findsOneWidget);

      // Verify actions exist
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
      expect(find.byType(Switch), findsWidgets);

      // Verify zero overflow
      expect(tester.takeException(), isNull);
    });
  });
}
