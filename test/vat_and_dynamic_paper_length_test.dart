import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/checkout_calculator.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/utils/printing/esc_pos_generator.dart';
import 'package:cafe_and_brews/src/utils/printing/pdf_receipt_builder.dart';
import 'package:cafe_and_brews/src/utils/printing/preparation_ticket_data.dart';
import 'package:cafe_and_brews/src/utils/printing/printer_config.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';
import 'package:cafe_and_brews/src/utils/printing/web_receipt_html_builder.dart';

double _calcReceiptHeight(
  ReceiptData receipt, {
  PrinterConfig config = const PrinterConfig(),
}) {
  final printablePoints = config.paperWidth.printableWidthMm * PdfPageFormat.mm;
  final style = ThermalReceiptPdfStyle.forConfig(
    config: config,
    pageWidth: printablePoints,
  );
  return PdfReceiptBuilder.calculateReceiptHeightPoints(
    receipt: receipt,
    style: style,
    config: config,
  );
}

double _calcTicketHeight(
  PreparationTicketData ticket, {
  PrinterConfig config = const PrinterConfig(),
}) {
  final printablePoints = config.paperWidth.printableWidthMm * PdfPageFormat.mm;
  final style = ThermalReceiptPdfStyle.forConfig(
    config: config,
    pageWidth: printablePoints,
  );
  return PdfReceiptBuilder.calculateTicketHeightPoints(
    ticket: ticket,
    style: style,
    config: config,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const productLatte = Product(
    id: 'latte',
    name: 'Spanish Latte',
    categoryId: 'coffee',
    price: 160.0,
    description: 'Espresso with condensed and fresh milk',
    badge: 'Popular',
    modifierGroupIds: [],
  );

  const productCroissant = Product(
    id: 'croissant',
    name: 'Butter Croissant',
    categoryId: 'pastries',
    price: 95.0,
    description: 'Flaky golden pastry',
    badge: '',
    modifierGroupIds: [],
  );

  group('VAT ON vs OFF Order Calculations', () {
    const calcService = OrderCalculationService(
      vatRate: 0.12,
      vatEnabled: true,
    );
    const checkoutCalc = CheckoutCalculator();

    test(
      'VAT ON (default 12%): preserves Philippine retail inclusive math',
      () {
        final cartItem = CartItem(
          product: productLatte,
          quantity: 1,
          selectedModifiers: const [],
        );

        final totals = calcService.calculate(
          cartItems: [cartItem],
          discountAmount: 0,
          serviceChargeRate: 0,
          cashReceived: 200,
          vatEnabled: true,
        );

        expect(totals.vatEnabled, isTrue);
        expect(totals.grossAmount, 160.0);
        expect(totals.subtotal, 160.0);
        // 160 / 1.12 = 142.86
        expect(totals.vatableSales, closeTo(142.86, 0.01));
        // 160 - 142.86 = 17.14
        expect(totals.vatAmount, closeTo(17.14, 0.01));
        expect(totals.tax, totals.vatAmount);
        expect(totals.total, 160.0);
        expect(totals.change, 40.0);
        expect(
          totals.vatableSales + totals.tax,
          closeTo(totals.grossAmount, 0.01),
        );

        final summary = checkoutCalc.summarize(
          cartItems: [cartItem],
          discountAmount: 0,
          taxRate: 0.12,
          serviceChargeRate: 0,
          cashReceived: 200,
          vatEnabled: true,
        );
        expect(summary.vatEnabled, isTrue);
        expect(summary.vatableSales, closeTo(142.86, 0.01));
        expect(summary.tax, closeTo(17.14, 0.01));
        expect(summary.total, 160.0);
      },
    );

    test(
      'VAT OFF: zeroes tax, vatable sales, and exempt sales without altering gross',
      () {
        final cartItem = CartItem(
          product: productLatte,
          quantity: 1,
          selectedModifiers: const [],
        );

        final totals = calcService.calculate(
          cartItems: [cartItem],
          discountAmount: 0,
          serviceChargeRate: 0,
          cashReceived: 200,
          vatEnabled: false,
        );

        expect(totals.vatEnabled, isFalse);
        expect(totals.grossAmount, 160.0);
        expect(totals.subtotal, 160.0);
        expect(totals.vatableSales, 0.0);
        expect(totals.vatAmount, 0.0);
        expect(totals.tax, 0.0);
        expect(totals.vatExemptSales, 0.0);
        expect(totals.vatExemptionAmount, 0.0);
        expect(totals.total, 160.0);
        expect(totals.change, 40.0);

        final summary = checkoutCalc.summarize(
          cartItems: [cartItem],
          discountAmount: 0,
          taxRate: 0.12,
          serviceChargeRate: 0,
          cashReceived: 200,
          vatEnabled: false,
        );
        expect(summary.vatEnabled, isFalse);
        expect(summary.vatableSales, 0.0);
        expect(summary.tax, 0.0);
        expect(summary.total, 160.0);
      },
    );

    test(
      'VAT OFF with discount and service charge applies direct calculation',
      () {
        final items = [
          CartItem(
            product: productLatte,
            quantity: 2,
            selectedModifiers: const [],
          ), // 320
          CartItem(
            product: productCroissant,
            quantity: 1,
            selectedModifiers: const [],
          ), // 95
        ]; // gross 415

        final totals = calcService.calculate(
          cartItems: items,
          discountAmount: 15.0,
          serviceChargeRate: 0.05, // 5% of gross 415 = 20.75
          cashReceived: 500,
          vatEnabled: false,
        );

        expect(totals.vatEnabled, isFalse);
        expect(totals.subtotal, 415.0);
        expect(totals.discount, 15.0);
        expect(totals.tax, 0.0);
        expect(totals.vatableSales, 0.0);
        expect(totals.serviceCharge, closeTo(20.75, 0.01));
        // Total = 415 - 15 + 20.75 = 420.75
        expect(totals.total, closeTo(420.75, 0.01));
        expect(totals.change, closeTo(79.25, 0.01));
      },
    );
  });

  group('VAT ON vs OFF Receipt Formatting', () {
    ReceiptData createReceipt({required bool vatEnabled}) {
      return ReceiptData(
        orderId: 'ORD-VAT-TEST',
        sequence: 101,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Maria',
        createdAt: DateTime(2026, 10, 1, 9, 30),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you for visiting!',
        vatEnabled: vatEnabled,
        items: const [
          ReceiptItem(
            name: 'Spanish Latte',
            quantity: 1,
            unitPrice: 160.0,
            lineTotal: 160.0,
          ),
        ],
        subtotal: 160.0,
        discount: 0.0,
        tax: vatEnabled ? 17.14 : 0.0,
        serviceCharge: 0.0,
        total: 160.0,
        cashReceived: 200.0,
        change: 40.0,
        vatableSales: vatEnabled ? 142.86 : 0.0,
        vatExemptSales: 0.0,
      );
    }

    test('ESC/POS: VAT ON prints Tax/VAT and Vatable breakdown', () {
      final receipt = createReceipt(vatEnabled: true);
      final generator = EscPosGenerator(config: const PrinterConfig());
      final bytes = generator.buildReceiptBytes(receipt);
      final text = latin1.decode(bytes, allowInvalid: true);

      expect(text, contains('VAT Incl.'));
      expect(text, contains('Vatable Sales'));
      expect(text, contains('142.86'));
      expect(text, contains('17.14'));
    });

    test(
      'ESC/POS: VAT OFF completely omits Tax/VAT and VAT breakdown without zero values',
      () {
        final receipt = createReceipt(vatEnabled: false);
        final generator = EscPosGenerator(config: const PrinterConfig());
        final bytes = generator.buildReceiptBytes(receipt);
        final text = latin1.decode(bytes, allowInvalid: true);

        expect(text, isNot(contains('VAT Incl.')));
        expect(text, isNot(contains('Vatable Sales')));
        expect(text, isNot(contains('VAT 0.00')));
        expect(text, isNot(contains('VAT (0%) 0.00')));
        expect(text, isNot(contains('VAT Exempt')));
        expect(text, isNot(contains('Zero Rated')));
        // Subtotal omitted when identical to total (no discount or service charge)
        expect(text, isNot(contains('Subtotal')));
        expect(text, contains('TOTAL'));
        expect(text, contains('Cash'));
        expect(text, contains('Change'));
      },
    );

    test('Web HTML: VAT ON renders VAT table rows', () {
      final receipt = createReceipt(vatEnabled: true);
      final html = WebReceiptHtmlBuilder.buildReceiptHtml(receipt);

      expect(html, contains('Vatable Sales'));
      expect(html, contains('VAT Incl.'));
      expect(html, contains('142.86'));
      expect(html, contains('17.14'));
    });

    test('Web HTML: VAT OFF completely omits VAT table rows', () {
      final receipt = createReceipt(vatEnabled: false);
      final html = WebReceiptHtmlBuilder.buildReceiptHtml(receipt);

      expect(html, isNot(contains('Vatable Sales')));
      expect(html, isNot(contains('VAT Incl.')));
      expect(html, isNot(contains('VAT 0.00')));
      expect(html, isNot(contains('VAT (0%) 0.00')));
      expect(html, isNot(contains('Subtotal')));
      expect(html, contains('TOTAL'));
    });

    test('PDF Receipt: builds cleanly for both VAT ON and VAT OFF', () async {
      final receiptVatOn = createReceipt(vatEnabled: true);
      final receiptVatOff = createReceipt(vatEnabled: false);

      const builder = PdfReceiptBuilder(config: PrinterConfig());
      final bytesOn = await builder.buildPdfBytes(receiptVatOn);
      final bytesOff = await builder.buildPdfBytes(receiptVatOff);

      expect(bytesOn, isNotEmpty);
      expect(bytesOff, isNotEmpty);

      // VAT OFF receipt height is shorter because the VAT section and tax rows are omitted
      final heightOn = _calcReceiptHeight(receiptVatOn);
      final heightOff = _calcReceiptHeight(receiptVatOff);
      expect(heightOff, lessThan(heightOn));
    });
  });

  group('Continuous Roll Dynamic Paper Length Scaling', () {
    test('1-item short receipt calculates to compact height (~200-250pt)', () {
      final shortReceipt = ReceiptData(
        orderId: 'ORD-SHORT',
        sequence: 1,
        orderType: 'Take-out',
        paymentType: 'CASH',
        cashierName: 'Alex',
        createdAt: DateTime(2026, 10, 1, 8, 0),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        vatEnabled: false,
        items: const [
          ReceiptItem(
            name: 'Americano',
            quantity: 1,
            unitPrice: 110.0,
            lineTotal: 110.0,
          ),
        ],
        subtotal: 110.0,
        discount: 0.0,
        tax: 0.0,
        serviceCharge: 0.0,
        total: 110.0,
        cashReceived: 200.0,
        change: 90.0,
      );

      final height = _calcReceiptHeight(
        shortReceipt,
        config: const PrinterConfig(paperWidth: PaperWidth.mm80),
      );

      // Compact receipts should stay below the paper budget; no minimum blank feed.
      expect(height, inExclusiveRange(0.0, 260.0));
    });

    test('multi-item receipt scales height dynamically and proportionally', () {
      final multiItemReceipt = ReceiptData(
        orderId: 'ORD-LONG',
        sequence: 2,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Alex',
        createdAt: DateTime(2026, 10, 1, 8, 15),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'BIR Permit No. 12345\nThank you for choosing Haven!',
        vatEnabled: true,
        items: const [
          ReceiptItem(
            name: 'Spanish Latte with Sweet Condensed Milk',
            quantity: 2,
            unitPrice: 160.0,
            lineTotal: 320.0,
            modifierLabels: ['Oat Milk Alternative', 'Double Espresso Shot'],
          ),
          ReceiptItem(
            name: 'Caramel Macchiato Grande',
            quantity: 1,
            unitPrice: 145.0,
            lineTotal: 145.0,
            modifierLabels: ['Sugar Free Vanilla', 'Extra Drizzle'],
          ),
          ReceiptItem(
            name: 'Freshly Baked Croissant with Butter & Blueberry Jam',
            quantity: 2,
            unitPrice: 95.0,
            lineTotal: 190.0,
          ),
          ReceiptItem(
            name: 'Matcha Green Tea Latte',
            quantity: 1,
            unitPrice: 150.0,
            lineTotal: 150.0,
            modifierLabels: ['Soy Milk', 'Less Sweet'],
          ),
        ],
        subtotal: 805.0,
        discount: 25.0,
        tax: 83.57,
        serviceCharge: 15.0,
        total: 875.0,
        cashReceived: 1000.0,
        change: 125.0,
        vatableSales: 696.43,
      );

      final shortReceipt = ReceiptData(
        orderId: 'ORD-SHORT-2',
        sequence: 3,
        orderType: 'Take-out',
        paymentType: 'CASH',
        cashierName: 'Alex',
        createdAt: DateTime(2026, 10, 1, 8, 20),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        vatEnabled: true,
        items: const [
          ReceiptItem(
            name: 'Americano',
            quantity: 1,
            unitPrice: 110.0,
            lineTotal: 110.0,
          ),
        ],
        subtotal: 110.0,
        discount: 0.0,
        tax: 11.79,
        serviceCharge: 0.0,
        total: 110.0,
        cashReceived: 200.0,
        change: 90.0,
        vatableSales: 98.21,
      );

      final heightMulti = _calcReceiptHeight(
        multiItemReceipt,
        config: const PrinterConfig(paperWidth: PaperWidth.mm80),
      );
      final heightShort = _calcReceiptHeight(
        shortReceipt,
        config: const PrinterConfig(paperWidth: PaperWidth.mm80),
      );

      // More content increases height without enforcing unnecessary paper usage.
      expect(heightMulti, greaterThan(heightShort));
    });

    test('58mm paper width scales dynamically and supports compact layout', () {
      final receipt1 = ReceiptData(
        orderId: 'ORD-58MM-1',
        sequence: 4,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Maria',
        createdAt: DateTime(2026, 10, 1, 9, 0),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        vatEnabled: false,
        items: const [
          ReceiptItem(
            name: 'Americano',
            quantity: 1,
            unitPrice: 110.0,
            lineTotal: 110.0,
          ),
        ],
        subtotal: 110.0,
        discount: 0.0,
        tax: 0.0,
        serviceCharge: 0.0,
        total: 110.0,
        cashReceived: 200.0,
        change: 90.0,
      );

      final receipt4 = ReceiptData(
        orderId: 'ORD-58MM-4',
        sequence: 5,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Maria',
        createdAt: DateTime(2026, 10, 1, 9, 0),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        vatEnabled: false,
        items: const [
          ReceiptItem(
            name: 'Americano',
            quantity: 1,
            unitPrice: 110.0,
            lineTotal: 110.0,
          ),
          ReceiptItem(
            name: 'Spanish Latte',
            quantity: 2,
            unitPrice: 160.0,
            lineTotal: 320.0,
          ),
          ReceiptItem(
            name: 'Croissant',
            quantity: 1,
            unitPrice: 95.0,
            lineTotal: 95.0,
          ),
          ReceiptItem(
            name: 'Matcha Latte',
            quantity: 1,
            unitPrice: 150.0,
            lineTotal: 150.0,
          ),
        ],
        subtotal: 675.0,
        discount: 0.0,
        tax: 0.0,
        serviceCharge: 0.0,
        total: 675.0,
        cashReceived: 1000.0,
        change: 325.0,
      );

      final height1 = _calcReceiptHeight(
        receipt1,
        config: const PrinterConfig(paperWidth: PaperWidth.mm58),
      );
      final height4 = _calcReceiptHeight(
        receipt4,
        config: const PrinterConfig(paperWidth: PaperWidth.mm58),
      );

      // On 58mm roll, 4-item receipt is proportionally taller than 1-item receipt
      expect(height4, greaterThan(height1 + 25.0));
      expect(height1, inExclusiveRange(0.0, 240.0));
    });
  });

  group('Kitchen / Barista Preparation Ticket', () {
    final ticket = PreparationTicketData(
      orderId: 'ORD-TICKET-01',
      sequence: 42,
      orderType: 'Dine In',
      customerName: 'Juan Dela Cruz',
      note: 'Extra hot espresso, table 12',
      createdAt: DateTime(2026, 10, 1, 10, 0),
      items: const [
        PreparationTicketItem(
          name: 'Flat White',
          quantity: 2,
          modifierLabels: ['Oat Milk', 'Extra Shot'],
        ),
        PreparationTicketItem(name: 'Chocolate Croissant', quantity: 1),
      ],
    );

    test(
      'Preparation ticket contains NO prices, currencies, or financial totals in ESC/POS',
      () {
        final generator = EscPosGenerator(config: const PrinterConfig());
        final bytes = generator.buildPreparationTicketBytes(ticket);
        final text = latin1.decode(bytes, allowInvalid: true);

        // Expected ticket content
        expect(text, contains('ORDER #42'));
        expect(text, contains('DINE IN'));
        expect(text, contains('Juan Dela Cruz'));
        expect(text, contains('FLAT WHITE'));
        expect(text, contains('OAT MILK'));
        expect(text, contains('EXTRA SHOT'));
        expect(text, contains('CHOCOLATE CROISSANT'));
        expect(text, contains('Extra hot espresso, table 12'));
        expect(text, isNot(contains('END OF ORDER')));

        // ABSOLUTELY NO financial data
        expect(text, isNot(contains('₱')));
        expect(text, isNot(contains('PHP')));
        expect(text, isNot(contains('Subtotal')));
        expect(text, isNot(contains('TOTAL')));
        expect(text, isNot(contains('Total:')));
        expect(text, isNot(contains('VAT')));
        expect(text, isNot(contains('Tax')));
        expect(text, isNot(contains('Cash Received')));
        expect(text, isNot(contains('Change')));
        expect(text, isNot(contains('Discount')));
        expect(text, isNot(contains('.00')));
      },
    );

    test('Preparation ticket contains NO financial totals in Web HTML', () {
      final html = WebReceiptHtmlBuilder.buildPreparationTicketHtml(ticket);

      expect(html, contains('Prep Ticket'));
      expect(html, contains('#42'));
      expect(html, contains('Juan Dela Cruz'));
      expect(html, contains('FLAT WHITE'));
      expect(html, contains('OAT MILK'));
      expect(html, isNot(contains('END OF ORDER')));

      expect(html, isNot(contains('₱')));
      expect(html, isNot(contains('Subtotal')));
      expect(html, isNot(contains('TOTAL')));
      expect(html, isNot(contains('VAT')));
      expect(html, isNot(contains('Tax')));
      expect(html, isNot(contains('Cash Received')));
      expect(html, isNot(contains('Discount')));
    });

    test(
      'Preparation ticket PDF builds dynamically with compact height',
      () async {
        const builder = PdfReceiptBuilder(config: PrinterConfig());
        final pdfBytes = await builder.buildPreparationTicketPdf(ticket);

        expect(pdfBytes, isNotEmpty);

        final height = _calcTicketHeight(
          ticket,
          config: const PrinterConfig(paperWidth: PaperWidth.mm80),
        );
        // Compact ticket should be ~140-230pt
        expect(height, inExclusiveRange(0.0, 230.0));
      },
    );
  });

  group('Minimal Paper Feed & Cutter Optimization', () {
    test(
      'autoCut: true feeds minimal line (1 line) before cutting command',
      () {
        final receipt = ReceiptData(
          orderId: 'ORD-CUT',
          sequence: 1,
          orderType: 'Dine In',
          paymentType: 'CASH',
          cashierName: 'Maria',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          vatEnabled: false,
          items: const [
            ReceiptItem(
              name: 'Latte',
              quantity: 1,
              unitPrice: 160.0,
              lineTotal: 160.0,
            ),
          ],
          subtotal: 160.0,
          discount: 0.0,
          tax: 0.0,
          serviceCharge: 0.0,
          total: 160.0,
          cashReceived: 200.0,
          change: 40.0,
        );

        final generator = EscPosGenerator(
          config: const PrinterConfig(autoCut: true, feedLines: 5),
        );
        final bytes = generator.buildReceiptBytes(receipt);

        // In EscPosGenerator:
        // if (config.autoCut) {
        //   bytes.addAll([0x1B, 0x64, 0x01]); // ESC d 1: feed 1 line
        //   bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // GS V 66 0: cut
        // }
        final cutSeq = [0x1D, 0x56, 0x42, 0x00];
        final feed1Seq = [0x1B, 0x64, 0x01];

        bool containsSequence(List<int> target, List<int> pattern) {
          for (int i = 0; i <= target.length - pattern.length; i++) {
            bool match = true;
            for (int j = 0; j < pattern.length; j++) {
              if (target[i + j] != pattern[j]) {
                match = false;
                break;
              }
            }
            if (match) return true;
          }
          return false;
        }

        expect(containsSequence(bytes, cutSeq), isTrue);
        expect(containsSequence(bytes, feed1Seq), isTrue);
      },
    );

    test(
      'autoCut: false feeds clamped lines (1..3) without cutting command',
      () {
        final receipt = ReceiptData(
          orderId: 'ORD-NO-CUT',
          sequence: 1,
          orderType: 'Dine In',
          paymentType: 'CASH',
          cashierName: 'Maria',
          createdAt: DateTime(2026, 10, 1, 10, 0),
          storeName: 'Haven & Co.',
          storeAddress: '123 Coffee Lane',
          storeContact: '0917-123-4567',
          receiptHeader: 'Official Receipt',
          receiptFooter: 'Thank you!',
          vatEnabled: false,
          items: const [
            ReceiptItem(
              name: 'Latte',
              quantity: 1,
              unitPrice: 160.0,
              lineTotal: 160.0,
            ),
          ],
          subtotal: 160.0,
          discount: 0.0,
          tax: 0.0,
          serviceCharge: 0.0,
          total: 160.0,
          cashReceived: 200.0,
          change: 40.0,
        );

        final generator = EscPosGenerator(
          config: const PrinterConfig(autoCut: false, feedLines: 10),
        );
        final bytes = generator.buildReceiptBytes(receipt);

        final cutSeq = [0x1D, 0x56, 0x42, 0x00];
        // Clamped to 3 lines: ESC d 3 -> 0x1B, 0x64, 0x03
        final feedClampedSeq = [0x1B, 0x64, 0x03];

        bool containsSequence(List<int> target, List<int> pattern) {
          for (int i = 0; i <= target.length - pattern.length; i++) {
            bool match = true;
            for (int j = 0; j < pattern.length; j++) {
              if (target[i + j] != pattern[j]) {
                match = false;
                break;
              }
            }
            if (match) return true;
          }
          return false;
        }

        expect(containsSequence(bytes, cutSeq), isFalse);
        expect(containsSequence(bytes, feedClampedSeq), isTrue);
      },
    );
  });

  group(
    'Controller VAT Settings Persistence and Historical Order Preservation',
    () {
      test(
        'VAT setting defaults to ON and toggling persists across reloads',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});

          final repository = InMemoryCoffeePosRepository();
          final controller = CoffeePosController(repository: repository);
          await controller.initialize();

          expect(controller.vatEnabled, isTrue);

          // Disable VAT
          controller.updateVatEnabled(false);
          expect(controller.vatEnabled, isFalse);

          await controller.flushPersistence();

          // Reload into new controller instance
          final reloaded = CoffeePosController(repository: repository);
          await reloaded.initialize();

          expect(reloaded.vatEnabled, isFalse);

          // Re-enable VAT
          reloaded.updateTaxSettings(
            vatEnabled: true,
            taxRate: 0.12,
            serviceChargeRate: 0.05,
          );
          expect(reloaded.vatEnabled, isTrue);
          expect(reloaded.taxRate, 0.12);
          expect(reloaded.serviceChargeRate, 0.05);

          await reloaded.flushPersistence();

          final reloaded2 = CoffeePosController(repository: repository);
          await reloaded2.initialize();
          expect(reloaded2.vatEnabled, isTrue);
          expect(reloaded2.taxRate, 0.12);
          expect(reloaded2.serviceChargeRate, 0.05);
        },
      );

      test(
        'historical orders preserve their original vatEnabled state even when setting changes',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});

          final repository = InMemoryCoffeePosRepository();
          final controller = CoffeePosController(repository: repository);
          await controller.initialize();

          // Step 1: Place Order 1 while VAT is ON
          expect(controller.vatEnabled, isTrue);
          controller.addProductToCart(controller.products.first);
          final order1 = await controller.checkout();
          expect(order1, isNotNull);
          expect(order1!.vatEnabled, isTrue);
          expect(order1.tax, greaterThan(0));

          // Step 2: Switch VAT to OFF
          controller.updateVatEnabled(false);
          expect(controller.vatEnabled, isFalse);

          // Step 3: Place Order 2 while VAT is OFF
          controller.addProductToCart(controller.products.first);
          final order2 = await controller.checkout();
          expect(order2, isNotNull);
          expect(order2!.vatEnabled, isFalse);
          expect(order2.tax, 0.0);

          // Step 4: Verify recent orders in controller
          expect(controller.recentOrders, hasLength(2));
          final recentOrder2 = controller.recentOrders.firstWhere(
            (o) => o.id == order2.id,
          );
          final recentOrder1 = controller.recentOrders.firstWhere(
            (o) => o.id == order1.id,
          );
          expect(recentOrder1.vatEnabled, isTrue);
          expect(recentOrder2.vatEnabled, isFalse);

          await controller.flushPersistence();

          // Step 5: Reload controller and verify historical persistence
          final reloaded = CoffeePosController(repository: repository);
          await reloaded.initialize();

          expect(reloaded.vatEnabled, isFalse); // Current active setting
          final persistedOrder1 = reloaded.recentOrders.firstWhere(
            (o) => o.id == order1.id,
          );
          final persistedOrder2 = reloaded.recentOrders.firstWhere(
            (o) => o.id == order2.id,
          );

          expect(
            persistedOrder1.vatEnabled,
            isTrue,
            reason: 'Historical Order 1 must retain VAT ON',
          );
          expect(persistedOrder1.tax, order1.tax);

          expect(
            persistedOrder2.vatEnabled,
            isFalse,
            reason: 'Historical Order 2 must retain VAT OFF',
          );
          expect(persistedOrder2.tax, 0.0);

          // Step 6: Verify ReceiptData converted from both retains accurate vatEnabled
          final receipt1 = ReceiptData.fromOrderRecord(
            order: persistedOrder1,
            storeName: controller.storeName,
            storeAddress: controller.storeAddress,
            storeContact: controller.storeContact,
            receiptHeader: controller.receiptHeader,
            receiptFooter: controller.receiptFooter,
          );
          final receipt2 = ReceiptData.fromOrderRecord(
            order: persistedOrder2,
            storeName: controller.storeName,
            storeAddress: controller.storeAddress,
            storeContact: controller.storeContact,
            receiptHeader: controller.receiptHeader,
            receiptFooter: controller.receiptFooter,
          );

          expect(receipt1.vatEnabled, isTrue);
          expect(receipt2.vatEnabled, isFalse);
        },
      );
    },
  );
}
