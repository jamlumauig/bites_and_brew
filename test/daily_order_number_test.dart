import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_layout.dart';
import 'package:cafe_and_brews/src/utils/printing/printer_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Daily Order Number format (YYYYMMDD-001, YYYYMMDD-002...) tests', () {
    test('formatDailyOrderNumber formats date and sequence correctly', () {
      final date1 = DateTime(2026, 10, 2);
      expect(formatDailyOrderNumber(date1, 1), '20261002-001');
      expect(formatDailyOrderNumber(date1, 2), '20261002-002');
      expect(formatDailyOrderNumber(date1, 42), '20261002-042');
      expect(formatDailyOrderNumber(date1, 100), '20261002-100');
      expect(formatDailyOrderNumber(date1, 1000), '20261002-1000');

      final nextDay = DateTime(2026, 10, 3);
      expect(formatDailyOrderNumber(nextDay, 1), '20261003-001');
    });

    test('OrderRecord and OrderQueueRecord provide orderNumber', () {
      final now = DateTime(2026, 10, 2, 10, 30);
      final record = OrderRecord(
        id: 'ORD-1',
        sequence: 1,
        status: OrderStatus.paid,
        orderType: 'Dine-in',
        paymentType: PaymentType.cash,
        cashierName: 'Jam',
        createdAt: now,
        subtotal: 100,
        discount: 0,
        tax: 12,
        serviceCharge: 0,
        total: 100,
        cashReceived: 100,
        change: 0,
        items: const [],
      );

      expect(record.orderNumber, '20261002-001');

      final queue = OrderQueueRecord(
        id: 'Q-ORD-1',
        sequence: 1,
        status: OrderQueueStatus.preparing,
        customerName: 'Customer A',
        orderType: 'Dine-in',
        createdAt: now,
        items: const [],
      );

      expect(queue.displayOrderNumber, '20261002-001');
    });

    test('ReceiptData and PreparationTicketData include daily order number in headers', () {
      final now = DateTime(2026, 10, 2, 14, 15);
      final order = OrderRecord(
        id: 'ORD-20261002-005',
        sequence: 5,
        status: OrderStatus.paid,
        orderType: 'Take-out',
        paymentType: PaymentType.cash,
        cashierName: 'Jam',
        createdAt: now,
        subtotal: 120,
        discount: 0,
        tax: 0,
        serviceCharge: 0,
        total: 120,
        cashReceived: 150,
        change: 30,
        items: const [],
      );

      final receipt = ReceiptData.fromOrderRecord(
        order: order,
        storeName: 'Haven & Co.',
        storeAddress: 'Ragan Sur, Delfin Albano Isabela',
        storeContact: '09123456789',
        receiptHeader: '',
        receiptFooter: 'Thank you!',
        includeKitchen: true,
      );

      expect(receipt.displayOrderNumber, '20261002-005');
      expect(receipt.preparationTicket!.displayOrderNumber, '20261002-005');

      final layout = ReceiptLayout(const PrinterConfig(paperWidth: PaperWidth.mm80));
      final customerLines = layout.customer(receipt);
      final customerText = customerLines.map((l) => l.left).join('\n');
      expect(customerText, contains('Order #20261002-005 • Take-out'));

      final kitchenLines = layout.kitchen(receipt.preparationTicket!);
      final kitchenText = kitchenLines.map((l) => l.left).join('\n');
      expect(kitchenText, contains('ORDER #20261002-005 • TAKE-OUT • 2:15 PM'));
    });

    test('CoffeePosController computes daily sequence resetting per day', () async {
      final repo = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repo);
      await controller.initialize();

      final today = DateTime.now();
      final todayDateStr =
          '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

      final product = controller.products.first;
      controller.addProductToCart(product, quantity: 1);
      controller.updateCashReceived(500);

      final order1 = await controller.checkout();
      expect(order1, isNotNull);
      expect(order1!.sequence, 1);
      expect(order1.orderNumber, '$todayDateStr-001');

      // Next order on same day increments sequence by 1
      controller.addProductToCart(product, quantity: 1);
      controller.updateCashReceived(500);
      final order2 = await controller.checkout();
      expect(order2, isNotNull);
      expect(order2!.sequence, 2);
      expect(order2.orderNumber, '$todayDateStr-002');

      // Next order on same day increments sequence by 1 again
      controller.addProductToCart(product, quantity: 1);
      controller.updateCashReceived(500);
      final order3 = await controller.checkout();
      expect(order3, isNotNull);
      expect(order3!.sequence, 3);
      expect(order3.orderNumber, '$todayDateStr-003');
    });
  });
}
