import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/reports/pos_reports_dashboard.dart';
import 'package:cafe_and_brews/src/ui/widgets/reports/reports_export_service.dart';

void main() {
  OrderRecord createSampleOrder({
    required String id,
    required String orderNumber,
    required DateTime createdAt,
    required double total,
    OrderStatus status = OrderStatus.paid,
    PaymentType paymentType = PaymentType.cash,
    String orderType = 'dine-in',
    String cashierName = 'Jam',
    List<OrderLineSnapshot>? items,
  }) {
    return OrderRecord(
      id: id,
      sequence: 1,
      orderNumber: orderNumber,
      status: status,
      orderType: orderType,
      paymentType: paymentType,
      cashierName: cashierName,
      createdAt: createdAt,
      subtotal: total,
      discount: 0,
      tax: 0,
      serviceCharge: 0,
      total: total,
      cashReceived: total,
      change: 0,
      items: items ??
          [
            OrderLineSnapshot(
              lineId: 'line-1',
              productId: 'latte',
              productName: 'Signature Latte',
              unitPrice: total,
              quantity: 1,
              modifierLabels: const ['16 oz', 'Oat Milk'],
              lineTotal: total,
              categoryId: 'coffee',
              categoryName: 'Coffee',
            ),
          ],
    );
  }

  group('Reports Date Range & Historical Filtering', () {
    test('Correctly filters transactions spanning multiple years (2024 to 2026)', () {
      final orders = [
        createSampleOrder(
          id: 'ord-2023',
          orderNumber: '20231231-001',
          createdAt: DateTime(2023, 12, 31, 23, 59),
          total: 100,
        ),
        createSampleOrder(
          id: 'ord-2024',
          orderNumber: '20240101-001',
          createdAt: DateTime(2024, 1, 1, 10, 0),
          total: 150,
        ),
        createSampleOrder(
          id: 'ord-2025',
          orderNumber: '20250615-001',
          createdAt: DateTime(2025, 6, 15, 14, 30),
          total: 200,
        ),
        createSampleOrder(
          id: 'ord-2026',
          orderNumber: '20261003-001',
          createdAt: DateTime(2026, 10, 3, 11, 0),
          total: 350,
        ),
        createSampleOrder(
          id: 'ord-2027',
          orderNumber: '20270101-001',
          createdAt: DateTime(2027, 1, 1, 9, 0),
          total: 500,
        ),
      ];

      // Custom range: Jan 1, 2024 to Dec 31, 2026
      final start = DateTime(2024, 1, 1, 0, 0, 0);
      final end = DateTime(2026, 12, 31, 23, 59, 59);

      final inRange = orders.where((o) => !o.createdAt.isBefore(start) && !o.createdAt.isAfter(end)).toList();

      expect(inRange.length, 3);
      expect(inRange.map((o) => o.id), containsAll(['ord-2024', 'ord-2025', 'ord-2026']));
      expect(inRange.map((o) => o.id), isNot(contains('ord-2023')));
      expect(inRange.map((o) => o.id), isNot(contains('ord-2027')));

      final totalSales = inRange.fold<double>(0.0, (s, o) => s + o.total);
      expect(totalSales, 700.0);
    });

    test('Correctly separates refunds and cancellations from paid sales', () {
      final orders = [
        createSampleOrder(
          id: 'paid-1',
          orderNumber: '001',
          createdAt: DateTime(2026, 10, 3, 9, 0),
          total: 250,
          status: OrderStatus.paid,
        ),
        createSampleOrder(
          id: 'paid-2',
          orderNumber: '002',
          createdAt: DateTime(2026, 10, 3, 10, 0),
          total: 150,
          status: OrderStatus.paid,
        ),
        createSampleOrder(
          id: 'ref-1',
          orderNumber: '003',
          createdAt: DateTime(2026, 10, 3, 11, 0),
          total: 120,
          status: OrderStatus.refunded,
        ),
        createSampleOrder(
          id: 'void-1',
          orderNumber: '004',
          createdAt: DateTime(2026, 10, 3, 11, 30),
          total: 90,
          status: OrderStatus.voided,
        ),
      ];

      final paid = orders.where((o) => o.status == OrderStatus.paid).toList();
      final refunded = orders.where((o) => o.status == OrderStatus.refunded).toList();

      final totalSales = paid.fold<double>(0.0, (s, o) => s + o.total);
      final refundAmount = refunded.fold<double>(0.0, (s, o) => s + o.total);

      expect(paid.length, 2);
      expect(totalSales, 400.0);
      expect(refunded.length, 1);
      expect(refundAmount, 120.0);
    });
  });

  group('Reports Category Sales & Historical Preservation', () {
    test('Preserves snapshot category names and aggregates correctly', () {
      final order = createSampleOrder(
        id: 'ord-mix',
        orderNumber: '001',
        createdAt: DateTime(2026, 10, 3),
        total: 510,
        items: [
          const OrderLineSnapshot(
            lineId: 'l1',
            productId: 'latte',
            productName: 'Signature Latte',
            unitPrice: 145,
            quantity: 2,
            modifierLabels: [],
            lineTotal: 290,
            categoryId: 'coffee',
            categoryName: 'Coffee & Espresso',
          ),
          const OrderLineSnapshot(
            lineId: 'l2',
            productId: 'croissant',
            productName: 'Butter Croissant',
            unitPrice: 110,
            quantity: 2,
            modifierLabels: [],
            lineTotal: 220,
            categoryId: 'pastry',
            categoryName: 'Bakery & Pastries',
          ),
        ],
      );

      final categorySales = <String, double>{};
      for (final item in order.items) {
        final cat = item.categoryName ?? 'Other';
        categorySales[cat] = (categorySales[cat] ?? 0.0) + item.lineTotal;
      }

      expect(categorySales['Coffee & Espresso'], 290.0);
      expect(categorySales['Bakery & Pastries'], 220.0);
    });
  });

  group('Reports Export Service', () {
    test('Exports CSV with complete metadata and itemized columns', () async {
      const service = ReportsExportService();
      final startDate = DateTime(2026, 10, 1);
      final endDate = DateTime(2026, 10, 3);

      final orders = [
        createSampleOrder(
          id: 'ord-101',
          orderNumber: '20261001-001',
          createdAt: DateTime(2026, 10, 1, 14, 25),
          total: 290,
          cashierName: 'Jam',
          items: [
            const OrderLineSnapshot(
              lineId: 'l1',
              productId: 'cappuccino',
              productName: 'Cappuccino',
              unitPrice: 145,
              quantity: 2,
              modifierLabels: ['Oat Milk'],
              lineTotal: 290,
              categoryId: 'coffee',
              categoryName: 'Coffee',
            ),
          ],
        ),
      ];

      final csvPath = await service.exportToCsv(
        periodLabel: 'Oct 1, 2026 - Oct 3, 2026',
        startDate: startDate,
        endDate: endDate,
        orders: orders,
        totalSales: 290.0,
        totalOrders: 1,
        itemsSold: 2,
        avgOrderValue: 290.0,
      );

      final csvContent = File(csvPath).readAsStringSync();

      // Verify metadata & columns
      expect(csvContent, contains('LUNAN POS - Sales Report'));
      expect(csvContent, contains('Reporting Period,"Oct 1, 2026 - Oct 3, 2026"'));
      expect(csvContent, contains('Total Sales,290.00'));
      expect(csvContent, contains('Total Orders,1'));
      expect(csvContent, contains('Date,Time,Order #,Status,Order Type,Payment Method,Cashier,Category,Product,Quantity,Unit Price,Line Total'));
      expect(csvContent, contains('20261001-001'));
      expect(csvContent, contains('Cappuccino'));
      expect(csvContent, contains('Coffee'));
      expect(csvContent, contains('290.00'));
    });

    test('Builds PDF bytes successfully', () async {
      const service = ReportsExportService();
      final startDate = DateTime(2026, 10, 1);
      final endDate = DateTime(2026, 10, 3);

      final orders = [
        createSampleOrder(
          id: 'ord-101',
          orderNumber: '20261001-001',
          createdAt: DateTime(2026, 10, 1, 14, 25),
          total: 290,
        ),
      ];

      final bytes = await service.buildPdfBytes(
        periodLabel: 'Oct 1, 2026 - Oct 3, 2026',
        startDate: startDate,
        endDate: endDate,
        orders: orders,
        totalSales: 290.0,
        totalOrders: 1,
        itemsSold: 2,
        avgOrderValue: 290.0,
        categorySales: {'Coffee': 290.0},
        topProducts: [const MapEntry('Cappuccino', 2)],
      );

      expect(bytes, isNotEmpty);
      // PDF documents start with %PDF header
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46])); // %PDF
    });
  });

  group('PosReportsDashboard Widget Tests', () {
    testWidgets('Renders all KPI cards, date range presets, and detailed table', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = CoffeePosController(repository: InMemoryCoffeePosRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosReportsDashboard(
              controller: controller,
              compactLandscape: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and presets
      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('This Year'), findsOneWidget);
      expect(find.text('Custom Range'), findsOneWidget);

      // Check KPI Cards
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Average Order Value'), findsOneWidget);
      expect(find.text('Items Sold'), findsOneWidget);

      // Check Export Buttons
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.text('Print Report'), findsOneWidget);

      // Check Sections
      expect(find.text('Sales & Activity Trend'), findsOneWidget);
      expect(find.text('Sales by Category'), findsOneWidget);
      expect(find.text('Top Selling Products'), findsOneWidget);
      expect(find.text('Payment Method Breakdown'), findsOneWidget);
      expect(find.text('Detailed Sales Report'), findsOneWidget);
    });

    testWidgets('Tapping Custom Range opens Custom Date Range Dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = CoffeePosController(repository: InMemoryCoffeePosRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosReportsDashboard(
              controller: controller,
              compactLandscape: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Custom Range chip
      await tester.tap(find.text('Custom Range'));
      await tester.pumpAndSettle();

      // Verify custom date dialog appeared
      expect(find.text('Select Date Range'), findsOneWidget);
      expect(find.text('Quick Jump to Year:'), findsOneWidget);
      expect(find.text('From Date'), findsOneWidget);
      expect(find.text('To Date'), findsOneWidget);
      expect(find.text('Apply Range'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Select Date Range'), findsNothing);
    });
  });
}
