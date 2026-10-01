import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/utils/printing/esc_pos_generator.dart';
import 'package:cafe_and_brews/src/utils/printing/pdf_receipt_builder.dart';
import 'package:cafe_and_brews/src/utils/printing/web_receipt_html_builder.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/platform_printer_adapter.dart';
import 'package:cafe_and_brews/src/utils/printing/print_status.dart';
import 'package:cafe_and_brews/src/utils/printing/printer_config.dart';
import 'package:cafe_and_brews/src/utils/printing/preparation_ticket_data.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';
import 'package:cafe_and_brews/src/utils/printing/thermal_printer_service.dart';

class _RecordingPrinterAdapter implements PlatformPrinterAdapter {
  final List<String> printedJobIds = [];
  final List<PrinterConfig> configsUsed = [];
  final List<ReceiptData> customerReceipts = [];
  final List<PreparationTicketData> kitchenTickets = [];
  final List<Uint8List> rawEscPosOutputs = [];

  bool failCustomerPrint = false;
  bool failKitchenPrint = false;

  @override
  Future<PrintResult> printReceipt({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    printedJobIds.add(jobId);
    configsUsed.add(config);
    customerReceipts.add(receipt);
    rawEscPosOutputs.add(escPosBytes);

    if (failCustomerPrint) {
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Paper out or disconnected',
      );
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
    printedJobIds.add(jobId);
    configsUsed.add(config);
    kitchenTickets.add(ticket);
    rawEscPosOutputs.add(escPosBytes);

    if (failKitchenPrint) {
      return PrintResult(
        jobId: jobId,
        receiptId: ticket.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Kitchen printer communication timeout',
      );
    }

    return PrintResult(
      jobId: jobId,
      receiptId: ticket.orderId,
      status: PrintStatus.success,
    );
  }

  @override
  Future<bool> isPrinterAvailable(PrinterConfig config) async => true;
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

  group('1. Explicit standalone receipt and kitchen reprints', () {
    late _RecordingPrinterAdapter mockAdapter;
    late ThermalPrinterService printerService;

    setUp(() {
      mockAdapter = _RecordingPrinterAdapter();
      printerService = ThermalPrinterServiceImpl(adapter: mockAdapter);
      ThermalPrinterService.instance = printerService;
    });

    test(
      'Customer copy and kitchen copy have separate job identities and deduplication keys',
      () async {
        final receipt = ReceiptData(
          orderId: 'ORD-20261001-001',
          sequence: 42,
          orderType: 'Dine In',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Spanish Latte',
              quantity: 1,
              unitPrice: 160.0,
              lineTotal: 186.0,
              modifiers: [
                ReceiptModifier(
                  name: 'Regular Milk',
                  priceDelta: 0.0,
                  isDefault: true,
                ),
                ReceiptModifier(
                  name: 'Oat Milk',
                  priceDelta: 26.0,
                  isDefault: false,
                ),
              ],
            ),
          ],
          subtotal: 186.0,
          discount: 0.0,
          tax: 19.93,
          serviceCharge: 0.0,
          total: 186.0,
          cashReceived: 200.0,
          change: 14.0,
          vatableSales: 166.07,
          vatExemptSales: 0.0,
        );

        final ticket = PreparationTicketData(
          orderId: 'ORD-20261001-001',
          sequence: 42,
          orderType: 'Dine In',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          items: const [
            PreparationTicketItem(
              name: 'Spanish Latte',
              quantity: 1,
              modifierLabels: ['Regular Milk', 'Oat Milk'],
            ),
          ],
        );

        final customerConfig = const PrinterConfig(
          printerName: 'Primary Thermal',
        );
        final kitchenConfig = const PrinterConfig(
          printerName: 'Kitchen Thermal',
        );

        // Sequential print of Customer copy then Kitchen copy
        final customerResult = await printerService.printReceipt(
          receipt,
          config: customerConfig,
        );
        final kitchenResult = await printerService.printPreparationTicket(
          ticket,
          config: kitchenConfig,
        );

        expect(customerResult.status, PrintStatus.success);
        expect(customerResult.jobId, contains('ORD-20261001-001-CUSTOMER'));

        expect(kitchenResult.status, PrintStatus.success);
        expect(kitchenResult.jobId, contains('ORD-20261001-001-KITCHEN'));

        // Distinct jobs recorded
        expect(mockAdapter.printedJobIds.length, equals(2));
        expect(mockAdapter.printedJobIds[0], contains('CUSTOMER'));
        expect(mockAdapter.printedJobIds[1], contains('KITCHEN'));

        // Separate printer routing verified
        expect(mockAdapter.configsUsed[0].printerName, 'Primary Thermal');
        expect(mockAdapter.configsUsed[1].printerName, 'Kitchen Thermal');

        // Verify that kitchen copy was NOT blocked by 15-second deduplication of customer copy
        expect(kitchenResult.status, PrintStatus.success);

        // Verify deduplication on rapid duplicate kitchen ticket tap
        final duplicateKitchenResult = await printerService
            .printPreparationTicket(ticket, config: kitchenConfig);
        expect(duplicateKitchenResult.status, PrintStatus.failedBeforeSending);
        expect(
          duplicateKitchenResult.message,
          contains('already queued or printed'),
        );
      },
    );

    test(
      'Print failure of either ticket does not cancel or corrupt sales order',
      () async {
        mockAdapter.failCustomerPrint = true;
        mockAdapter.failKitchenPrint = false;

        final receipt = ReceiptData(
          orderId: 'ORD-FAIL-001',
          sequence: 99,
          orderType: 'Take Out',
          paymentType: 'GCASH',
          cashierName: 'Sam',
          createdAt: DateTime(2026, 10, 1, 11, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Cold Brew',
              quantity: 1,
              unitPrice: 120.0,
              lineTotal: 120.0,
            ),
          ],
          subtotal: 120.0,
          discount: 0.0,
          tax: 12.86,
          serviceCharge: 0.0,
          total: 120.0,
          cashReceived: 120.0,
          change: 0.0,
          vatableSales: 107.14,
          vatExemptSales: 0.0,
        );

        final ticket = PreparationTicketData(
          orderId: 'ORD-FAIL-001',
          sequence: 99,
          orderType: 'Take Out',
          createdAt: DateTime(2026, 10, 1, 11, 0),
          items: const [PreparationTicketItem(name: 'Cold Brew', quantity: 1)],
        );

        final customerRes = await printerService.printReceipt(
          receipt,
          config: const PrinterConfig(),
        );
        final kitchenRes = await printerService.printPreparationTicket(
          ticket,
          config: const PrinterConfig(),
        );

        expect(customerRes.status, PrintStatus.failedBeforeSending);
        expect(kitchenRes.status, PrintStatus.success);
      },
    );

    test(
      'Controller routes kitchen printer separately when configured',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final repository = InMemoryCoffeePosRepository();
        final controller = CoffeePosController(repository: repository);
        await controller.initialize();

        // Configure primary printer and separate kitchen printer
        controller.updatePrinterSettings(
          printerName: 'Front Thermal Printer',
          printerUrl: 'usb://front',
          autoPrintReceipts: true,
        );
        controller.updateKitchenPrinterSettings(
          printerName: 'Back Kitchen Barista Printer',
          printerUrl: 'tcp://192.168.1.50:9100',
        );

        expect(controller.printerName, 'Front Thermal Printer');
        expect(controller.kitchenPrinterName, 'Back Kitchen Barista Printer');
        expect(controller.kitchenPrinterUrl, 'tcp://192.168.1.50:9100');

        final product = controller.products.first;
        controller.addProductToCart(product);
        controller.updateCashReceived(500);

        final order = await controller.checkout();
        expect(order, isNotNull);

        // Print customer receipt
        await controller.printReceipt(order!);
        expect(
          mockAdapter.configsUsed.last.printerName,
          'Front Thermal Printer',
        );

        // Print kitchen ticket
        await controller.printPreparationTicketFromOrder(order);
        expect(
          mockAdapter.configsUsed.last.printerName,
          'Back Kitchen Barista Printer',
        );
        expect(
          mockAdapter.configsUsed.last.printerUrl,
          'tcp://192.168.1.50:9100',
        );
      },
    );
  });

  group('2. Customer Receipt Modifier Add-On Pricing & Default Suppression', () {
    test(
      'ESC/POS: prints modifier price deltas and suppresses default zero-cost modifiers',
      () {
        final generator = EscPosGenerator(
          config: const PrinterConfig(paperWidth: PaperWidth.mm80),
        );

        final receipt = ReceiptData(
          orderId: 'ORD-MOD-001',
          sequence: 1,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Spanish Latte',
              quantity: 1,
              unitPrice: 160.0,
              lineTotal: 186.0,
              modifiers: [
                ReceiptModifier(
                  name: 'Regular Milk',
                  priceDelta: 0.0,
                  isDefault: true,
                ),
                ReceiptModifier(
                  name: '16 oz',
                  priceDelta: 0.0,
                  isDefault: false,
                ),
                ReceiptModifier(
                  name: 'Oat Milk',
                  priceDelta: 26.0,
                  isDefault: false,
                ),
              ],
            ),
          ],
          subtotal: 186.0,
          discount: 0.0,
          tax: 19.93,
          serviceCharge: 0.0,
          total: 186.0,
          cashReceived: 200.0,
          change: 14.0,
          vatableSales: 166.07,
          vatExemptSales: 0.0,
        );

        final bytes = generator.buildReceiptBytes(receipt);
        final rawText = latin1.decode(bytes);
        final text = _stripEscPos(rawText);

        // Default zero-cost modifier MUST be suppressed
        expect(text, isNot(contains('Regular Milk')));

        // Non-default zero-cost modifier MUST appear without +₱0.00
        expect(text, contains('16 oz'));
        expect(text, isNot(contains('16 oz  +₱0.00')));
        expect(text, isNot(contains('16 oz  +0.00')));

        // Price-altering modifier MUST show price delta
        expect(text, contains('Oat Milk'));
        expect(text.contains('+P26.00') || text.contains('+₱26.00'), isTrue);
      },
    );

    test(
      'HTML: renders modifier price deltas and suppresses default zero-cost modifiers',
      () {
        final receipt = ReceiptData(
          orderId: 'ORD-MOD-002',
          sequence: 2,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Matcha Latte',
              quantity: 1,
              unitPrice: 170.0,
              lineTotal: 205.0,
              modifiers: [
                ReceiptModifier(
                  name: 'Regular Milk',
                  priceDelta: 0.0,
                  isDefault: true,
                ),
                ReceiptModifier(
                  name: 'Large 20oz',
                  priceDelta: 15.0,
                  isDefault: false,
                ),
                ReceiptModifier(
                  name: 'Extra Shot',
                  priceDelta: 20.0,
                  isDefault: false,
                ),
                ReceiptModifier(
                  name: 'Less Ice',
                  priceDelta: 0.0,
                  isDefault: false,
                ),
              ],
            ),
          ],
          subtotal: 205.0,
          discount: 0.0,
          tax: 21.96,
          serviceCharge: 0.0,
          total: 205.0,
          cashReceived: 500.0,
          change: 295.0,
          vatableSales: 183.04,
          vatExemptSales: 0.0,
        );

        final html = WebReceiptHtmlBuilder.buildReceiptHtml(
          receipt,
          config: const PrinterConfig(),
        );

        // Suppress default zero-cost modifier
        expect(html, isNot(contains('Regular Milk')));

        // Non-default zero-cost modifier displayed without price delta
        expect(html, contains('Less Ice'));
        expect(html, isNot(contains('+ Less Ice (+₱0.00)')));

        // Modifiers with price deltas displayed with (+₱XX.XX)
        expect(html, matches(RegExp(r'Large 20oz +\+₱15\.00')));
        expect(html, matches(RegExp(r'Extra Shot +\+₱20\.00')));
      },
    );

    test(
      'PDF Receipt: builds successfully with modifier pricing deltas',
      () async {
        final receipt = ReceiptData(
          orderId: 'ORD-MOD-003',
          sequence: 3,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Americano',
              quantity: 1,
              unitPrice: 130.0,
              lineTotal: 150.0,
              modifiers: [
                ReceiptModifier(
                  name: 'Single Origin',
                  priceDelta: 20.0,
                  isDefault: false,
                ),
                ReceiptModifier(
                  name: 'Standard Temp',
                  priceDelta: 0.0,
                  isDefault: true,
                ),
              ],
            ),
          ],
          subtotal: 150.0,
          discount: 0.0,
          tax: 16.07,
          serviceCharge: 0.0,
          total: 150.0,
          cashReceived: 200.0,
          change: 50.0,
          vatableSales: 133.93,
          vatExemptSales: 0.0,
        );

        final pdfBytes = await const PdfReceiptBuilder(
          config: PrinterConfig(),
        ).buildPdfBytes(receipt);
        expect(pdfBytes, isNotEmpty);
        expect(pdfBytes.length, greaterThan(100));
      },
    );
  });

  group('3. Kitchen / Barista Copy Omits All Financials', () {
    test(
      'ESC/POS preparation ticket contains modifiers and strictly zero financial data',
      () {
        final generator = EscPosGenerator(
          config: const PrinterConfig(paperWidth: PaperWidth.mm80),
        );

        final ticket = PreparationTicketData(
          orderId: 'ORD-KITCHEN-001',
          sequence: 55,
          orderType: 'Dine-in',
          customerName: 'Juan Dela Cruz',
          createdAt: DateTime(2026, 10, 1, 14, 30),
          note: 'Extra hot please',
          items: const [
            PreparationTicketItem(
              name: 'Caramel Macchiato',
              quantity: 2,
              modifierLabels: [
                'Regular Milk',
                '16 oz',
                'Extra Caramel',
                'Oat Milk',
              ],
            ),
          ],
        );

        final bytes = generator.buildPreparationTicketBytes(ticket);
        final rawText = latin1.decode(bytes);
        final text = _stripEscPos(rawText);

        // Verifies Order Header Banner
        expect(text, contains('ORDER #55'));
        expect(text, contains('DINE-IN'));
        expect(text, contains('Customer: Juan Dela Cruz'));
        expect(text, isNot(contains('ORD-KITCHEN-001'))); // No redundant ID.

        // Modifiers MUST be present on kitchen ticket (including Regular Milk for barista clarity)
        expect(text, contains('2x CARAMEL MACCHIATO'));
        expect(text, contains('REGULAR MILK'));
        expect(text, contains('16 OZ'));
        expect(text, contains('EXTRA CARAMEL'));
        expect(text, contains('OAT MILK'));
        expect(text, contains('NOTE: Extra hot please'));
        expect(text, isNot(contains('END OF ORDER')));

        // Strictly ZERO financial data
        expect(text, isNot(contains('₱')));
        expect(text, isNot(contains('\$')));
        expect(text, isNot(contains('Subtotal')));
        expect(text, isNot(contains('Total')));
        expect(text, isNot(contains('VAT')));
        expect(text, isNot(contains('Tax')));
        expect(text, isNot(contains('Cash')));
        expect(text, isNot(contains('Change')));
        expect(text, isNot(contains('Payment')));
      },
    );

    test('PDF preparation ticket builds successfully without errors', () async {
      final ticket = PreparationTicketData(
        orderId: 'ORD-KITCHEN-002',
        sequence: 56,
        orderType: 'Take Out',
        customerName: 'Maria',
        createdAt: DateTime(2026, 10, 1, 14, 35),
        items: const [
          PreparationTicketItem(
            name: 'Iced Americano',
            quantity: 1,
            modifierLabels: ['16 oz', 'Less Ice'],
          ),
        ],
      );

      final pdfBytes = await const PdfReceiptBuilder(
        config: PrinterConfig(),
      ).buildPreparationTicketPdf(ticket);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));
    });
  });

  group('4. Telephone & Placeholder Contact / Address Omission', () {
    test(
      'ESC/POS: omits telephone and address when empty, null, or placeholder strings',
      () {
        final generator = EscPosGenerator(
          config: const PrinterConfig(paperWidth: PaperWidth.mm80),
        );

        final receiptWithPlaceholders = ReceiptData(
          orderId: 'ORD-CONT-001',
          sequence: 1,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: 'Store address not set',
          storeContact: 'Store contact not set',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Espresso',
              quantity: 1,
              unitPrice: 100.0,
              lineTotal: 100.0,
            ),
          ],
          subtotal: 100.0,
          discount: 0.0,
          tax: 10.71,
          serviceCharge: 0.0,
          total: 100.0,
          cashReceived: 100.0,
          change: 0.0,
          vatableSales: 89.29,
          vatExemptSales: 0.0,
        );

        final text = _stripEscPos(
          latin1.decode(generator.buildReceiptBytes(receiptWithPlaceholders)),
        );

        expect(text, isNot(contains('Store contact not set')));
        expect(text, isNot(contains('Tel:')));
        expect(text, isNot(contains('Store address not set')));

        // Test with valid contact info
        final receiptWithValidInfo = ReceiptData(
          orderId: 'ORD-CONT-002',
          sequence: 2,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '456 Roasted Ave, Taguig',
          storeContact: '+63 917 888 9999',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Espresso',
              quantity: 1,
              unitPrice: 100.0,
              lineTotal: 100.0,
            ),
          ],
          subtotal: 100.0,
          discount: 0.0,
          tax: 10.71,
          serviceCharge: 0.0,
          total: 100.0,
          cashReceived: 100.0,
          change: 0.0,
          vatableSales: 89.29,
          vatExemptSales: 0.0,
        );

        final validText = _stripEscPos(
          latin1.decode(generator.buildReceiptBytes(receiptWithValidInfo)),
        );
        expect(validText, contains('456 Roasted Ave, Taguig'));
        expect(validText, contains('+63 917 888 9999'));
      },
    );

    test('HTML: omits placeholder contact lines', () {
      final receipt = ReceiptData(
        orderId: 'ORD-CONT-003',
        sequence: 3,
        orderType: 'Dine-in',
        paymentType: 'CASH',
        cashierName: 'Alex',
        createdAt: DateTime(2026, 10, 1, 10, 0),
        storeName: 'Haven & Co.',
        storeAddress: 'none',
        storeContact: 'n/a',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        items: const [
          ReceiptItem(
            name: 'Espresso',
            quantity: 1,
            unitPrice: 100.0,
            lineTotal: 100.0,
          ),
        ],
        subtotal: 100.0,
        discount: 0.0,
        tax: 10.71,
        serviceCharge: 0.0,
        total: 100.0,
        cashReceived: 100.0,
        change: 0.0,
        vatableSales: 89.29,
        vatExemptSales: 0.0,
      );

      final html = WebReceiptHtmlBuilder.buildReceiptHtml(
        receipt,
        config: const PrinterConfig(),
      );
      expect(html, isNot(contains('Tel:')));
      expect(html, isNot(contains('n/a')));
      expect(html, isNot(contains('none')));
    });
  });

  group('5. Subtotal Row Suppression Rules', () {
    test(
      'ESC/POS: Subtotal omitted when no adjustments exist, shown when discount exists',
      () {
        final generator = EscPosGenerator(
          config: const PrinterConfig(paperWidth: PaperWidth.mm80),
        );

        final receiptNoAdjustments = ReceiptData(
          orderId: 'ORD-SUB-001',
          sequence: 1,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Latte',
              quantity: 1,
              unitPrice: 150.0,
              lineTotal: 150.0,
            ),
          ],
          subtotal: 150.0,
          discount: 0.0,
          tax: 16.07,
          serviceCharge: 0.0,
          total: 150.0,
          cashReceived: 150.0,
          change: 0.0,
          vatableSales: 133.93,
          vatExemptSales: 0.0,
        );

        final textNoAdj = _stripEscPos(
          latin1.decode(generator.buildReceiptBytes(receiptNoAdjustments)),
        );
        // When subtotal == total and no discount/service charge, omit Subtotal row
        expect(textNoAdj, isNot(contains('Subtotal')));
        expect(textNoAdj, contains('TOTAL'));

        final receiptWithDiscount = ReceiptData(
          orderId: 'ORD-SUB-002',
          sequence: 2,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          items: const [
            ReceiptItem(
              name: 'Latte',
              quantity: 1,
              unitPrice: 150.0,
              lineTotal: 150.0,
            ),
          ],
          subtotal: 150.0,
          discount: 30.0,
          tax: 12.86,
          serviceCharge: 0.0,
          total: 120.0,
          cashReceived: 150.0,
          change: 30.0,
          vatableSales: 107.14,
          vatExemptSales: 0.0,
        );

        final textWithDiscount = _stripEscPos(
          latin1.decode(generator.buildReceiptBytes(receiptWithDiscount)),
        );
        // When discount exists, Subtotal MUST be shown
        expect(textWithDiscount, contains('Subtotal'));
        expect(textWithDiscount, contains('Discount'));
        expect(textWithDiscount, contains('-P30.00'));
        expect(textWithDiscount, contains('TOTAL'));
      },
    );

    test('HTML: Subtotal omitted when no adjustments exist', () {
      final receipt = ReceiptData(
        orderId: 'ORD-SUB-003',
        sequence: 3,
        orderType: 'Dine-in',
        paymentType: 'CASH',
        cashierName: 'Alex',
        createdAt: DateTime(2026, 10, 1, 10, 0),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        items: const [
          ReceiptItem(
            name: 'Latte',
            quantity: 1,
            unitPrice: 150.0,
            lineTotal: 150.0,
          ),
        ],
        subtotal: 150.0,
        discount: 0.0,
        tax: 16.07,
        serviceCharge: 0.0,
        total: 150.0,
        cashReceived: 150.0,
        change: 0.0,
        vatableSales: 133.93,
        vatExemptSales: 0.0,
      );

      final html = WebReceiptHtmlBuilder.buildReceiptHtml(
        receipt,
        config: const PrinterConfig(),
      );
      expect(html, isNot(contains('<td>Subtotal</td>')));
      expect(html, contains('TOTAL'));
    });
  });

  group('6. Single Thank-You Footer Output', () {
    test(
      'ESC/POS: prints configured footer only once without duplicate thank you lines',
      () {
        final generator = EscPosGenerator(
          config: const PrinterConfig(paperWidth: PaperWidth.mm80),
        );

        final receipt = ReceiptData(
          orderId: 'ORD-FOOTER-001',
          sequence: 1,
          orderType: 'Dine-in',
          paymentType: 'CASH',
          cashierName: 'Alex',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Please visit us again!',
          items: const [
            ReceiptItem(
              name: 'Latte',
              quantity: 1,
              unitPrice: 150.0,
              lineTotal: 150.0,
            ),
          ],
          subtotal: 150.0,
          discount: 0.0,
          tax: 16.07,
          serviceCharge: 0.0,
          total: 150.0,
          cashReceived: 150.0,
          change: 0.0,
          vatableSales: 133.93,
          vatExemptSales: 0.0,
        );

        final text = _stripEscPos(
          latin1.decode(generator.buildReceiptBytes(receipt)),
        );

        // Configured footer appears
        expect(text, contains('Please visit us again!'));

        // Hardcoded "Thank you for visiting!" should NOT be present
        expect(text, isNot(contains('Thank you for visiting!')));

        // Count occurrences of "Thank you"
        final occurrences = 'Thank you'.allMatches(text).length;
        expect(
          occurrences,
          0,
        ); // since configured footer was 'Please visit us again!'
      },
    );

    test('HTML: prints single configured footer', () {
      final receipt = ReceiptData(
        orderId: 'ORD-FOOTER-002',
        sequence: 2,
        orderType: 'Dine-in',
        paymentType: 'CASH',
        cashierName: 'Alex',
        createdAt: DateTime(2026, 10, 1, 10, 0),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'See you next time!',
        items: const [
          ReceiptItem(
            name: 'Latte',
            quantity: 1,
            unitPrice: 150.0,
            lineTotal: 150.0,
          ),
        ],
        subtotal: 150.0,
        discount: 0.0,
        tax: 16.07,
        serviceCharge: 0.0,
        total: 150.0,
        cashReceived: 150.0,
        change: 0.0,
        vatableSales: 133.93,
        vatExemptSales: 0.0,
      );

      final html = WebReceiptHtmlBuilder.buildReceiptHtml(
        receipt,
        config: const PrinterConfig(),
      );
      expect(html, contains('See you next time!'));
      expect(html, isNot(contains('Thank you for visiting!')));
    });
  });
}
