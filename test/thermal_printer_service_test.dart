import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/utils/printing/esc_pos_generator.dart';
import 'package:cafe_and_brews/src/utils/printing/pdf_receipt_builder.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/platform_printer_adapter.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/printer_resolver.dart';
import 'package:cafe_and_brews/src/utils/printing/print_status.dart';
import 'package:cafe_and_brews/src/utils/printing/printer_config.dart';
import 'package:cafe_and_brews/src/utils/printing/preparation_ticket_data.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_validator.dart';
import 'package:cafe_and_brews/src/utils/printing/thermal_printer_service.dart';
import 'package:printing/printing.dart';

class MockPlatformPrinterAdapter implements PlatformPrinterAdapter {
  int printCount = 0;
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
    return PrintResult(
      jobId: jobId,
      receiptId: ticket.orderId,
      status: PrintStatus.success,
    );
  }

  @override
  Future<bool> isPrinterAvailable(PrinterConfig config) async {
    return true;
  }
}

ReceiptData createValidReceipt({
  String orderId = 'ORD-001',
  double subtotal = 300.0,
  double discount = 20.0,
  double tax = 33.6,
  double serviceCharge = 0.0,
  double total = 313.6,
  String paymentType = 'CASH',
  double cashReceived = 500.0,
  double change = 186.4,
  List<ReceiptItem>? items,
}) {
  return ReceiptData(
    orderId: orderId,
    sequence: 1,
    orderType: 'Dine In',
    paymentType: paymentType,
    cashierName: 'Maria',
    createdAt: DateTime(2026, 9, 22, 10, 30),
    storeName: 'Haven & Co.',
    storeAddress: '123 Coffee Lane, Metro Manila',
    storeContact: '0917-123-4567',
    receiptHeader: 'Official Receipt',
    receiptFooter: 'BIR Permit No. 12345',
    items: items ??
        const [
          ReceiptItem(
            name: 'Spanish Latte',
            quantity: 1,
            unitPrice: 160.0,
            lineTotal: 160.0,
            modifierLabels: ['Oat Milk', 'Extra Shot'],
          ),
          ReceiptItem(
            name: 'Caramel Macchiato with Whipped Cream & Vanilla Syrup',
            quantity: 1,
            unitPrice: 140.0,
            lineTotal: 140.0,
          ),
        ],
    subtotal: subtotal,
    discount: discount,
    tax: tax,
    serviceCharge: serviceCharge,
    total: total,
    cashReceived: cashReceived,
    change: change,
    vatableSales: 280.0,
    vatExemptSales: 0.0,
  );
}

bool containsSequence(List<int> bytes, List<int> sequence) {
  if (sequence.isEmpty || bytes.length < sequence.length) return false;
  for (var i = 0; i <= bytes.length - sequence.length; i++) {
    var match = true;
    for (var j = 0; j < sequence.length; j++) {
      if (bytes[i + j] != sequence[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptValidator', () {
    test('passes valid receipt with consistent totals', () {
      final receipt = createValidReceipt();
      final error = ReceiptValidator.validate(receipt);
      expect(error, isNull);
    });

    test('rejects missing receipt ID', () {
      final receipt = createValidReceipt(orderId: '   ');
      final error = ReceiptValidator.validate(receipt);
      expect(error, contains('Missing receipt ID'));
    });

    test('rejects receipt with empty items', () {
      final receipt = createValidReceipt(items: []);
      final error = ReceiptValidator.validate(receipt);
      expect(error, contains('Receipt has no items'));
    });

    test('rejects item with non-positive quantity', () {
      final receipt = createValidReceipt(
        items: const [
          ReceiptItem(name: 'Espresso', quantity: 0, unitPrice: 100, lineTotal: 100),
        ],
      );
      final error = ReceiptValidator.validate(receipt);
      expect(error, contains('quantity must be greater than zero'));
    });

    test('rejects item total sum mismatch with subtotal', () {
      final receipt = createValidReceipt(
        subtotal: 500.0, // items sum to 300.0
        total: 513.6,
      );
      final error = ReceiptValidator.validate(receipt);
      expect(error, contains('Receipt subtotal does not match item totals sum'));
    });

    test('rejects calculation mismatch on total', () {
      // subtotal: 300, discount: 20, tax: 33.6, total should be 313.6, set to 400
      final receipt = createValidReceipt(total: 400.0);
      final error = ReceiptValidator.validate(receipt);
      expect(error, contains('Receipt total does not match calculations'));
    });

    test('rejects cash payment with insufficient cash received', () {
      final receipt = createValidReceipt(
        paymentType: 'CASH',
        total: 313.6,
        cashReceived: 200.0, // less than total
        change: 0.0,
      );
      final error = ReceiptValidator.validate(receipt);
      expect(error, contains('Cash received is less than receipt total'));
    });

    test('rejects cash payment with incorrect change calculation', () {
      final receipt = createValidReceipt(
        paymentType: 'CASH',
        total: 313.6,
        cashReceived: 500.0,
        change: 50.0, // should be 186.4
      );
      final error = ReceiptValidator.validate(receipt);
      expect(error, contains('Change calculation mismatch'));
    });
  });

  group('EscPosGenerator (80mm Thermal Mode)', () {
    test('generates valid ESC/POS byte sequence with 48 chars wrapping and minimal feed', () {
      final receipt = createValidReceipt();
      final config = const PrinterConfig(
        paperWidth: PaperWidth.mm80,
        charactersPerLine: 48,
        feedLines: 2,
        autoCut: true,
        openCashDrawer: true,
      );
      final generator = EscPosGenerator(config: config);
      final bytes = generator.buildReceiptBytes(receipt);

      expect(bytes, isNotEmpty);
      // Starts with ESC @ (0x1B, 0x40)
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);

      // Contains cash drawer kick command ESC p (0x1B, 0x70)
      expect(containsSequence(bytes, [0x1B, 0x70]), isTrue);

      // Contains paper cut command GS V (0x1D, 0x56)
      expect(containsSequence(bytes, [0x1D, 0x56]), isTrue);

      // Converts Peso symbol to P to avoid garbled output on thermal printers
      final text = String.fromCharCodes(bytes);
      expect(text.contains('Spanish Latte'), isTrue);
      expect(text.contains('Caramel Macchiato'), isTrue);
      expect(text.contains('160.00'), isTrue);
      expect(text.contains('313.60'), isTrue);
      expect(text.contains('₱'), isFalse);
    });

    test('respects autoCut: false by omitting cut command', () {
      final receipt = createValidReceipt();
      final config = const PrinterConfig(
        paperWidth: PaperWidth.mm80,
        autoCut: false,
        openCashDrawer: false,
      );
      final generator = EscPosGenerator(config: config);
      final bytes = generator.buildReceiptBytes(receipt);

      // Does not contain cut command GS V (0x1D, 0x56)
      expect(containsSequence(bytes, [0x1D, 0x56]), isFalse);
      // Does not contain cash drawer kick ESC p (0x1B, 0x70)
      expect(containsSequence(bytes, [0x1B, 0x70]), isFalse);
    });
  });

  group('PdfReceiptBuilder', () {
    test('generates compact 80mm PDF receipt bytes in memory', () async {
      final receipt = createValidReceipt();
      const config = PrinterConfig(
        paperWidth: PaperWidth.mm80,
        compactReceiptStyle: true,
      );
      final builder = PdfReceiptBuilder(config: config);
      final pdfBytes = await builder.buildPdfBytes(receipt);

      expect(pdfBytes, isNotEmpty);
      // PDF starts with %PDF
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, '%PDF');
    });
  });

  group('ThermalPrinterServiceImpl', () {
    late MockPlatformPrinterAdapter mockAdapter;
    late ThermalPrinterServiceImpl service;

    setUp(() {
      mockAdapter = MockPlatformPrinterAdapter();
      service = ThermalPrinterServiceImpl(adapter: mockAdapter);
    });

    test('valid receipt prints successfully via platform adapter', () async {
      final receipt = createValidReceipt(orderId: 'ORD-SUCCESS-1');
      final result = await service.printReceipt(receipt);

      expect(result.isSuccess, isTrue);
      expect(result.status, PrintStatus.success);
      expect(mockAdapter.printCount, 1);
      expect(service.recentJobs, isNotEmpty);
      expect(service.recentJobs.first.status, PrintStatus.success);
    });

    test('zero paper movement on validation error - adapter is never called', () async {
      final invalidReceipt = createValidReceipt(orderId: 'ORD-FAIL-1', items: []);
      final result = await service.printReceipt(invalidReceipt);

      expect(result.isSuccess, isFalse);
      expect(result.status, PrintStatus.failedBeforeSending);
      expect(result.canRetry, isTrue);
      expect(result.message, contains('Receipt has no items'));
      // Absolutely ZERO communication with printer
      expect(mockAdapter.printCount, 0);
    });

    test('rapid duplicate print within 15 seconds is blocked without touching printer', () async {
      final receipt = createValidReceipt(orderId: 'ORD-DUP-1');

      // First print succeeds
      final firstResult = await service.printReceipt(receipt);
      expect(firstResult.isSuccess, isTrue);
      expect(mockAdapter.printCount, 1);

      // Second print within 15s is blocked
      final secondResult = await service.printReceipt(receipt);
      expect(secondResult.isSuccess, isFalse);
      expect(secondResult.status, PrintStatus.failedBeforeSending);
      expect(secondResult.message, contains('already queued or printed'));
      // Adapter was NOT called again
      expect(mockAdapter.printCount, 1);
    });

    test('manual reprint is allowed even within 15 seconds', () async {
      final receipt = createValidReceipt(orderId: 'ORD-REPRINT-1');

      // First print succeeds
      final firstResult = await service.printReceipt(receipt);
      expect(firstResult.isSuccess, isTrue);
      expect(mockAdapter.printCount, 1);

      // Manual reprint succeeds
      final reprintResult = await service.printReceipt(receipt, manualReprint: true);
      expect(reprintResult.isSuccess, isTrue);
      expect(mockAdapter.printCount, 2);
    });

    test('handles unknown transmission status without allowing auto-retry', () async {
      mockAdapter.onPrint = (jobId, receipt, config) {
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.unknown,
          message: 'Transmission interrupted',
        );
      };

      final receipt = createValidReceipt(orderId: 'ORD-UNKNOWN-1');
      final result = await service.printReceipt(receipt);

      expect(result.status, PrintStatus.unknown);
      expect(result.isSuccess, isFalse);
      expect(result.canRetry, isFalse); // DO NOT retry automatically
    });

    test('handles canceled print dialog', () async {
      mockAdapter.onPrint = (jobId, receipt, config) {
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.canceled,
          message: 'Print cancelled by user',
        );
      };

      final receipt = createValidReceipt(orderId: 'ORD-CANCEL-1');
      final result = await service.printReceipt(receipt);

      expect(result.status, PrintStatus.canceled);
      expect(result.canRetry, isTrue);
    });

    test('print queue serializes concurrent jobs sequentially', () async {
      final executionOrder = <String>[];
      mockAdapter.onPrint = (jobId, receipt, config) {
        executionOrder.add(receipt.orderId);
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.success,
        );
      };

      final receiptA = createValidReceipt(orderId: 'ORD-A');
      final receiptB = createValidReceipt(orderId: 'ORD-B');

      // Launch both concurrently
      final futureA = service.printReceipt(receiptA);
      final futureB = service.printReceipt(receiptB);

      await Future.wait([futureA, futureB]);

      expect(executionOrder, ['ORD-A', 'ORD-B']);
      expect(mockAdapter.printCount, 2);
    });
  });

  group('ThermalTransport & PrinterConfig Defaults', () {
    test('ThermalTransport.fromString recognizes direct and no prompt variants', () {
      expect(ThermalTransport.fromString('Direct print (no prompt)'), ThermalTransport.direct);
      expect(ThermalTransport.fromString('direct'), ThermalTransport.direct);
      expect(ThermalTransport.fromString('no prompt'), ThermalTransport.direct);
      expect(ThermalTransport.fromString('silent'), ThermalTransport.direct);
      expect(ThermalTransport.fromString('auto'), ThermalTransport.direct);
      expect(ThermalTransport.fromString(null), ThermalTransport.direct);
      expect(ThermalTransport.fromString('System dialog'), ThermalTransport.systemDialog);
      expect(ThermalTransport.fromString('Thermal printer app'), ThermalTransport.thermalApp);
      expect(ThermalTransport.fromString('Network (ESC/POS)'), ThermalTransport.networkEscPos);
    });

    test('PrinterConfig defaults to 80mm roll, Direct Print, and GEZHI_micro_printer', () {
      const config = PrinterConfig();
      expect(config.paperWidth, PaperWidth.mm80);
      expect(config.paperWidth.millimeterWidth, 80);
      expect(config.charactersPerLine, 48);
      expect(config.transport, ThermalTransport.direct);
      expect(config.printerName, 'GEZHI_micro_printer');
      expect(config.feedLines, 2);
    });
  });

  group('PrinterResolver Auto-Detection', () {
    test('picks thermal printer matching gezhi keyword', () {
      const p1 = Printer(url: 'usb://HP/LaserJet', name: 'HP LaserJet Pro');
      const p2 = Printer(url: 'usb://GEZHI/micro-printer?serial=4', name: 'GEZHI_micro_printer');
      final detected = PrinterResolver.autoDetectPrinter([p1, p2]);
      expect(detected, isNotNull);
      expect(detected!.name, 'GEZHI_micro_printer');
    });

    test('picks thermal printer matching officom keyword', () {
      const p1 = Printer(url: 'canon://ip', name: 'Canon Office Scanner');
      const p2 = Printer(url: 'usb://officom', name: 'Officom 80mm Series');
      final detected = PrinterResolver.autoDetectPrinter([p1, p2]);
      expect(detected, isNotNull);
      expect(detected!.name, 'Officom 80mm Series');
    });

    test('picks system default printer when no thermal keywords match', () {
      const p1 = Printer(url: 'usb://generic/1', name: 'Generic Office Printer');
      const p2 = Printer(url: 'usb://generic/2', name: 'Deskjet 2000', isDefault: true);
      final detected = PrinterResolver.autoDetectPrinter([p1, p2]);
      expect(detected, isNotNull);
      expect(detected!.name, 'Deskjet 2000');
    });

    test('falls back to first printer when no keywords and no default flag', () {
      const p1 = Printer(url: 'usb://first', name: 'First Printer');
      const p2 = Printer(url: 'usb://second', name: 'Second Printer');
      final detected = PrinterResolver.autoDetectPrinter([p1, p2]);
      expect(detected, isNotNull);
      expect(detected!.name, 'First Printer');
    });

    test('returns null when printer list is empty', () {
      expect(PrinterResolver.autoDetectPrinter([]), isNull);
    });
  });
}
