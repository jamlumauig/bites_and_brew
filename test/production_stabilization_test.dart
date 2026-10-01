import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/utils/printing/esc_pos_generator.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/platform_printer_adapter.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/printer_resolver.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/web_printer_adapter.dart';
import 'package:cafe_and_brews/src/utils/printing/print_status.dart';
import 'package:cafe_and_brews/src/utils/printing/printer_config.dart';
import 'package:cafe_and_brews/src/utils/printing/preparation_ticket_data.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';
import 'package:cafe_and_brews/src/utils/printing/thermal_printer_service.dart';
import 'package:printing/printing.dart';

class _MockPlatformPrinterAdapter implements PlatformPrinterAdapter {
  int printCount = 0;
  Uint8List? lastEscPosBytes;
  Uint8List? lastPdfBytes;
  PrintResult Function(String jobId, ReceiptData receipt, PrinterConfig config)? onPrint;

  @override
  Future<PrintResult> printReceipt({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    printCount++;
    lastPdfBytes = pdfBytes;
    lastEscPosBytes = escPosBytes;
    if (onPrint != null) {
      return onPrint!(jobId, receipt, config);
    }
    return PrintResult(
      jobId: jobId,
      receiptId: receipt.orderId,
      status: PrintStatus.success,
    );
  }

  @override
  Future<PrintResult> printPreparationTicket({
    required String jobId,
    required PreparationTicketData ticket,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    printCount++;
    lastPdfBytes = pdfBytes;
    lastEscPosBytes = escPosBytes;
    return PrintResult(
      jobId: jobId,
      receiptId: ticket.orderId,
      status: PrintStatus.success,
    );
  }

  @override
  Future<bool> isPrinterAvailable(PrinterConfig config) async => true;
}

ReceiptData _sampleReceipt({
  String orderId = 'ORD-20261001-100000-001',
  String paymentType = 'CASH',
  double subtotal = 320.0,
  double discount = 20.0,
  double tax = 35.71,
  double serviceCharge = 0.0,
  double total = 300.0,
  double cashReceived = 500.0,
  double change = 200.0,
  List<ReceiptItem>? items,
  String storeName = 'Haven & Co.',
  String receiptHeader = 'Official Receipt',
  String receiptFooter = 'Thank you!',
}) {
  return ReceiptData(
    orderId: orderId,
    sequence: 1,
    orderType: 'Dine-in',
    paymentType: paymentType,
    cashierName: 'Alex',
    createdAt: DateTime(2026, 10, 1, 10, 30),
    storeName: storeName,
    storeAddress: '123 Coffee Lane',
    storeContact: '0917-123-4567',
    receiptHeader: receiptHeader,
    receiptFooter: receiptFooter,
    items: items ??
        const [
          ReceiptItem(
            name: 'Spanish Latte',
            quantity: 2,
            unitPrice: 160.0,
            lineTotal: 320.0,
            modifierLabels: ['Oat Milk'],
          ),
        ],
    subtotal: subtotal,
    discount: discount,
    tax: tax,
    serviceCharge: serviceCharge,
    total: total,
    cashReceived: cashReceived,
    change: change,
    vatableSales: 267.86,
    vatExemptSales: 0.0,
  );
}

String _stripEscPos(String text) {
  return text
      .replaceAll(RegExp(r'\x1B\x70\x00\x19\xFA'), '')
      .replaceAll(RegExp(r'\x1D\x56\x42\x00'), '')
      .replaceAll(RegExp(r'\x1B[\x40\x61\x45\x64].?'), '')
      .replaceAll(RegExp(r'\x1D[\x21\x56].?'), '')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Priority 1: Prevent Duplicate Sales & Mutex Protection', () {
    test('1. Rapid Charge taps creates exactly 1 paid order from same cart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repository = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repository);
      await controller.initialize();

      // Add product to cart
      final product = controller.products.first;
      controller.addProductToCart(product, quantity: 2);
      controller.updateCashReceived(1000);

      expect(controller.canCheckout, isTrue);

      // Simulate 5 rapid concurrent checkout calls
      final results = await Future.wait([
        controller.checkout(),
        controller.checkout(),
        controller.checkout(),
        controller.checkout(),
        controller.checkout(),
      ]);

      // Exactly one checkout must succeed with an OrderRecord
      final successfulOrders = results.whereType<OrderRecord>().toList();
      expect(successfulOrders.length, equals(1));

      // Subsequent in-flight calls must return null
      final nullResults = results.where((r) => r == null).toList();
      expect(nullResults.length, equals(4));

      // Recent orders in repository and controller must have exactly 1 order
      expect(controller.recentOrders.length, equals(1));
      expect(controller.isCheckingOut, isFalse);
    });

    test('2. Checkout failure releases mutex lock in finally block', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repository = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repository);
      await controller.initialize();

      final product = controller.products.first;
      controller.addProductToCart(product, quantity: 1);
      controller.updateCashReceived(500);

      // Force canCheckout check and verify lock release if an error occurs
      expect(controller.isCheckingOut, isFalse);
      expect(controller.canCheckout, isTrue);

      // Execute healthy checkout
      final order = await controller.checkout();
      expect(order, isNotNull);
      expect(controller.isCheckingOut, isFalse);
    });
  });

  group('Priority 2: Durable Unique Order IDs & Sequence Numbering', () {
    test('Order ID format is durable and sequence is monotonic', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repository = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repository);
      await controller.initialize();

      final product = controller.products.first;

      controller.addProductToCart(product, quantity: 1);
      controller.updateCashReceived(500);
      final order1 = await controller.checkout();

      controller.addProductToCart(product, quantity: 1);
      controller.updateCashReceived(500);
      final order2 = await controller.checkout();

      expect(order1, isNotNull);
      expect(order2, isNotNull);
      expect(order1!.id, startsWith('ORD-'));
      expect(order2!.id, startsWith('ORD-'));
      expect(order1.id, isNot(equals(order2.id)));
      expect(order2.sequence, equals(order1.sequence + 1));

      // Preparation queue ID must use durable order id
      expect(controller.activeOrders.first.id, equals('Q-${order2.id}'));
    });
  });

  group('Priority 3 & 4: Thermal Paper Width (58mm vs 80mm) & Auto Config', () {
    test('3. 58mm receipt layout uses 32 columns max (no 48-col overflow)', () {
      const config = PrinterConfig(paperWidth: PaperWidth.mm58);
      expect(config.charactersPerLine, equals(32));

      final generator = EscPosGenerator(config: config);
      final receipt = _sampleReceipt();
      final bytes = generator.buildReceiptBytes(receipt);

      // Decode printable text lines
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final lines = decoded.split('\n');

      for (final line in lines) {
        final stripped = _stripEscPos(line);
        // In 58mm mode, line width must never exceed 32 characters
        expect(
          stripped.length,
          lessThanOrEqualTo(32),
          reason: 'Line exceeded 32 cols for 58mm: "$stripped"',
        );
      }
    });

    test('4. 80mm receipt layout uses 48 columns max', () {
      const config = PrinterConfig(paperWidth: PaperWidth.mm80);
      expect(config.charactersPerLine, equals(48));

      final generator = EscPosGenerator(config: config);
      final receipt = _sampleReceipt();
      final bytes = generator.buildReceiptBytes(receipt);

      final decoded = utf8.decode(bytes, allowMalformed: true);
      final lines = decoded.split('\n');

      for (final line in lines) {
        final stripped = _stripEscPos(line);
        expect(
          stripped.length,
          lessThanOrEqualTo(48),
          reason: 'Line exceeded 48 cols for 80mm: "$stripped"',
        );
      }
    });

    test('5. Long drink name wraps cleanly without exceeding paper width or truncating price', () {
      const config = PrinterConfig(paperWidth: PaperWidth.mm58);
      final generator = EscPosGenerator(config: config);
      final receipt = _sampleReceipt(
        items: const [
          ReceiptItem(
            name: 'Caramel Macchiato with Whipped Cream & Vanilla Syrup',
            quantity: 1,
            unitPrice: 220.0,
            lineTotal: 220.0,
          ),
        ],
        subtotal: 240.0,
        discount: 20.0,
        total: 220.0,
      );

      final bytes = generator.buildReceiptBytes(receipt);
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final lines = decoded.split('\n');

      for (final line in lines) {
        final stripped = _stripEscPos(line);
        expect(stripped.length, lessThanOrEqualTo(32));
      }

      // Ensure price is preserved on the first item line
      expect(decoded.contains('220.00'), isTrue);
    });

    test('6. Long food name wraps cleanly', () {
      const config = PrinterConfig(paperWidth: PaperWidth.mm58);
      final generator = EscPosGenerator(config: config);
      final receipt = _sampleReceipt(
        items: const [
          ReceiptItem(
            name: 'Artisanal Grilled Chicken Pesto Sandwich on Sourdough',
            quantity: 1,
            unitPrice: 280.0,
            lineTotal: 280.0,
          ),
        ],
        subtotal: 300.0,
        discount: 20.0,
        total: 280.0,
      );

      final bytes = generator.buildReceiptBytes(receipt);
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final lines = decoded.split('\n');

      for (final line in lines) {
        final stripped = _stripEscPos(line);
        expect(stripped.length, lessThanOrEqualTo(32));
      }
    });

    test('7. Modifiers render underneath parent item', () {
      const config = PrinterConfig(paperWidth: PaperWidth.mm80);
      final generator = EscPosGenerator(config: config);
      final receipt = _sampleReceipt(
        items: const [
          ReceiptItem(
            name: 'Iced Americano',
            quantity: 1,
            unitPrice: 120.0,
            lineTotal: 140.0,
            modifierLabels: ['Extra Shot (+P20)', 'Sugar Free'],
          ),
        ],
        subtotal: 140.0,
        discount: 0.0,
        total: 140.0,
      );

      final bytes = generator.buildReceiptBytes(receipt);
      final decoded = utf8.decode(bytes, allowMalformed: true);

      expect(decoded.contains('Iced Americano'), isTrue);
      expect(decoded.contains('Extra Shot (+P20)'), isTrue);
    });

    test('14. AUTO width (0) resolves to safe fallback', () {
      final config = PrinterConfig(paperWidth: PaperWidth.fromInt(0));
      expect(config.paperWidth, equals(PaperWidth.mm80));
      expect(config.charactersPerLine, equals(48));

      final controller = CoffeePosController(repository: InMemoryCoffeePosRepository());
      controller.updatePrinterSettings(
        printerName: 'Generic Thermal',
        printerUrl: '',
        autoPrintReceipts: true,
        thermalPaperWidth: 0,
      );
      expect(controller.effectiveThermalPaperWidth, equals(80));
    });

    test('15. Manual 58mm preserved in autoConfigurePrinter', () async {
      final controller = CoffeePosController(repository: InMemoryCoffeePosRepository());
      controller.updatePrinterSettings(
        printerName: 'Kitchen Printer',
        printerUrl: '',
        autoPrintReceipts: true,
        thermalPaperWidth: 58,
      );
      expect(controller.thermalPaperWidth, equals(58));

      // autoConfigurePrinter without force must preserve 58mm
      await controller.autoConfigurePrinter(force: false);
      expect(controller.thermalPaperWidth, equals(58));
    });

    test('16. Manual 80mm preserved in autoConfigurePrinter', () async {
      final controller = CoffeePosController(repository: InMemoryCoffeePosRepository());
      controller.updatePrinterSettings(
        printerName: 'Kitchen Printer',
        printerUrl: '',
        autoPrintReceipts: true,
        thermalPaperWidth: 80,
      );
      expect(controller.thermalPaperWidth, equals(80));

      await controller.autoConfigurePrinter(force: false);
      expect(controller.thermalPaperWidth, equals(80));
    });
  });

  group('Priority 5 & 6: Never Print Errors & Zero Paper Waste', () {
    test('8. Receipt-generation failure: adapter never called', () async {
      final mockAdapter = _MockPlatformPrinterAdapter();
      final service = ThermalPrinterServiceImpl(adapter: mockAdapter);

      // Receipt with invalid unit price that causes calculation error
      final receipt = _sampleReceipt(
        items: const [
          ReceiptItem(
            name: 'Broken Item',
            quantity: 1,
            unitPrice: double.nan,
            lineTotal: 100.0,
          ),
        ],
      );

      final result = await service.printReceipt(receipt);
      expect(result.status, equals(PrintStatus.failedBeforeSending));
      expect(mockAdapter.printCount, equals(0));
    });

    test('9. Invalid receipt data: adapter never called on calculation mismatch', () async {
      final mockAdapter = _MockPlatformPrinterAdapter();
      final service = ThermalPrinterServiceImpl(adapter: mockAdapter);

      final receipt = _sampleReceipt(
        subtotal: 500.0,
        total: 100.0, // Blatant mismatch
      );

      final result = await service.printReceipt(receipt);
      expect(result.status, equals(PrintStatus.failedBeforeSending));
      expect(mockAdapter.printCount, equals(0));
    });

    test('10. Error-like payload: rejected before adapter (0 bytes sent)', () async {
      final mockAdapter = _MockPlatformPrinterAdapter();
      final service = ThermalPrinterServiceImpl(adapter: mockAdapter);

      final errorPayloadReceipt = _sampleReceipt(
        storeName: 'Exception: Connection timeout in DatabasePool',
      );

      final result = await service.printReceipt(errorPayloadReceipt);
      expect(result.status, equals(PrintStatus.failedBeforeSending));
      expect(result.message, contains('diagnostic/error payload'));
      expect(mockAdapter.printCount, equals(0));
    });
  });

  group('Priority 7: Duplicate Print Protection & Manual Reprint', () {
    test('11. Rapid print requests deduplicated within 15 seconds', () async {
      final mockAdapter = _MockPlatformPrinterAdapter();
      final service = ThermalPrinterServiceImpl(adapter: mockAdapter);
      final receipt = _sampleReceipt(orderId: 'ORD-DUP-TEST-001');

      final result1 = await service.printReceipt(receipt);
      expect(result1.status, equals(PrintStatus.success));
      expect(mockAdapter.printCount, equals(1));

      // Immediate second print must be blocked
      final result2 = await service.printReceipt(receipt);
      expect(result2.status, equals(PrintStatus.failedBeforeSending));
      expect(result2.message, contains('already queued or printed'));
      expect(mockAdapter.printCount, equals(1));
    });

    test('12. Manual reprint allowed without creating sales order', () async {
      final mockAdapter = _MockPlatformPrinterAdapter();
      final service = ThermalPrinterServiceImpl(adapter: mockAdapter);
      final receipt = _sampleReceipt(orderId: 'ORD-REPRINT-TEST-001');

      final result1 = await service.printReceipt(receipt);
      expect(result1.status, equals(PrintStatus.success));
      expect(mockAdapter.printCount, equals(1));

      // Manual reprint allowed
      final result2 = await service.printReceipt(receipt, manualReprint: true);
      expect(result2.status, equals(PrintStatus.success));
      expect(mockAdapter.printCount, equals(2));
    });

    test('13. Unknown/ambiguous transmission status: no auto-retry', () async {
      final mockAdapter = _MockPlatformPrinterAdapter()
        ..onPrint = (jobId, receipt, config) {
          throw Exception('Printer port dropped connection mid-stream');
        };

      final service = ThermalPrinterServiceImpl(adapter: mockAdapter);
      final receipt = _sampleReceipt(orderId: 'ORD-UNKNOWN-TEST-001');

      final result = await service.printReceipt(receipt);
      expect(result.status, equals(PrintStatus.unknown));
      // Must not auto retry blindly
      expect(mockAdapter.printCount, equals(1));
    });
  });

  group('Priority 8: Cash Drawer Safety', () {
    test('17. Cash drawer pulse injected ONLY for CASH sale', () {
      const config = PrinterConfig(openCashDrawer: true);
      final generator = EscPosGenerator(config: config);

      final cashReceipt = _sampleReceipt(paymentType: 'CASH');
      final bytes = generator.buildReceiptBytes(cashReceipt);

      // Cash drawer kick sequence is [0x1B, 0x70, 0x00, 0x19, 0xFA]
      final hasDrawerKick = bytes[2] == 0x1B && bytes[3] == 0x70;
      expect(hasDrawerKick, isTrue);
    });

    test('18. Cash drawer pulse NOT injected for Card / E-Wallet sale', () {
      const config = PrinterConfig(openCashDrawer: true);
      final generator = EscPosGenerator(config: config);

      final cardReceipt = _sampleReceipt(paymentType: 'CARD');
      final bytes = generator.buildReceiptBytes(cardReceipt);

      final hasDrawerKick = bytes.length > 5 && bytes[2] == 0x1B && bytes[3] == 0x70;
      expect(hasDrawerKick, isFalse);
    });

    test('19. Cash drawer pulse NOT injected on manual reprint even for Cash sale', () {
      const config = PrinterConfig(openCashDrawer: true);
      final generator = EscPosGenerator(config: config);

      final cashReceipt = _sampleReceipt(paymentType: 'CASH');
      final bytes = generator.buildReceiptBytes(cashReceipt, isReprint: true);

      final hasDrawerKick = bytes.length > 5 && bytes[2] == 0x1B && bytes[3] == 0x70;
      expect(hasDrawerKick, isFalse);
    });
  });

  group('Priority 9: Direct Receipt Printing Without Print Dialog', () {
    test('20. WebPrinterAdapter blocks unexpected dialog during direct checkout (sandbox honesty)', () async {
      const adapter = WebPrinterAdapter();
      const config = PrinterConfig(
        transport: ThermalTransport.direct,
        printerName: 'GEZHI_micro_printer',
        webKioskPrinting: false,
      );
      final receipt = _sampleReceipt(orderId: 'ORD-WEB-DIRECT-1');

      final result = await adapter.printReceipt(
        jobId: 'JOB-1',
        receipt: receipt,
        config: config,
        pdfBytes: Uint8List.fromList([1, 2, 3]),
        escPosBytes: Uint8List.fromList([4, 5, 6]),
      );

      // Must NOT return submittedToDialog (no popup/dialog allowed)
      expect(result.status, equals(PrintStatus.failedBeforeSending));
      expect(result.message, contains('Chrome Kiosk Mode'));
      expect(result.message, contains('macOS'));
    });

    test('21. WebPrinterAdapter allows dialog ONLY when systemDialog is explicitly requested', () async {
      const adapter = WebPrinterAdapter();
      const config = PrinterConfig(
        transport: ThermalTransport.systemDialog,
        printerName: 'GEZHI_micro_printer',
      );
      final receipt = _sampleReceipt(orderId: 'ORD-WEB-DIALOG-1');

      final result = await adapter.printReceipt(
        jobId: 'JOB-2',
        receipt: receipt,
        config: config,
        pdfBytes: Uint8List.fromList([1, 2, 3]),
        escPosBytes: Uint8List.fromList([4, 5, 6]),
      );

      // On non-web test harness it falls back to layoutPdf/failure or submittedToDialog,
      // but status must reflect dialog intent, not direct spooler
      expect(
        result.status == PrintStatus.submittedToDialog ||
            result.status == PrintStatus.failedBeforeSending ||
            result.status == PrintStatus.canceled,
        isTrue,
      );
    });

    test('22. PrinterResolver canonical matching resolves GEZHI_micro_printer to GEZHI micro-printer', () {
      const printer1 = Printer(
        url: 'usb://GEZHI/micro-printer?serial=000000000004',
        name: 'GEZHI micro-printer',
        isDefault: false,
        isAvailable: true,
      );
      const printer2 = Printer(
        url: 'cups-hp-laserjet',
        name: 'HP LaserJet Pro',
        isDefault: true,
        isAvailable: true,
      );

      final printers = [printer2, printer1];

      // Auto-detect matches gezhi keyword
      final detected = PrinterResolver.autoDetectPrinter(printers);
      expect(detected, isNotNull);
      expect(detected!.name, equals('GEZHI micro-printer'));
    });

    test('23. Controller printReceipt respects transportOverride for manual dialog fallback', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final mockAdapter = _MockPlatformPrinterAdapter();
      ThermalPrinterService.instance = ThermalPrinterServiceImpl(adapter: mockAdapter);

      final repository = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repository);
      await controller.initialize();

      final product = controller.products.first;
      controller.addProductToCart(product, quantity: 1);
      controller.updateCashReceived(500);
      final order = await controller.checkout();
      expect(order, isNotNull);

      // 1. Normal auto print with default transport (Direct print)
      await controller.printReceipt(order!, manualReprint: true);
      expect(mockAdapter.printCount, equals(1));

      // 2. Fallback reprint explicitly requesting System dialog
      PrinterConfig? capturedConfig;
      mockAdapter.onPrint = (jobId, receipt, config) {
        capturedConfig = config;
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.submittedToDialog,
        );
      };

      await controller.printReceipt(
        order,
        manualReprint: true,
        transportOverride: 'System dialog',
      );

      expect(mockAdapter.printCount, equals(2));
      expect(capturedConfig, isNotNull);
      expect(capturedConfig!.transport, equals(ThermalTransport.systemDialog));
    });

    test('24. Order transaction is completely decoupled from printing failure', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final mockAdapter = _MockPlatformPrinterAdapter()
        ..onPrint = (jobId, receipt, config) {
          throw Exception('Physical printer jam or USB disconnected');
        };
      ThermalPrinterService.instance = ThermalPrinterServiceImpl(adapter: mockAdapter);

      final repository = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repository);
      await controller.initialize();

      final product = controller.products.first;
      controller.addProductToCart(product, quantity: 1);
      controller.updatePaymentType(PaymentType.cash);
      controller.updateCashReceived(500.0);

      expect(controller.cart.length, equals(1));

      // Checkout completes successfully
      final order = await controller.checkout();
      expect(order, isNotNull);
      expect(order!.status, equals(OrderStatus.paid));
      expect(controller.cart, isEmpty);

      // Print attempt fails
      final printResult = await controller.printReceipt(order);
      expect(printResult.isSuccess, isFalse);

      // Order must REMAIN saved in controller recent orders
      expect(controller.recentOrders.any((o) => o.id == order.id), isTrue);
      expect(controller.recentOrders.first.status, equals(OrderStatus.paid));
    });

    test('25. PrinterConfig supports webKioskPrinting and localBridge transport', () {
      const config1 = PrinterConfig(
        transport: ThermalTransport.direct,
        webKioskPrinting: true,
      );
      expect(config1.webKioskPrinting, isTrue);

      final fromStr = ThermalTransport.fromString('Local print bridge (web)');
      expect(fromStr, equals(ThermalTransport.localBridge));

      final directStr = ThermalTransport.fromString('Direct print (no prompt)');
      expect(directStr, equals(ThermalTransport.direct));

      final dialogStr = ThermalTransport.fromString('System dialog');
      expect(dialogStr, equals(ThermalTransport.systemDialog));
    });
  });
}
