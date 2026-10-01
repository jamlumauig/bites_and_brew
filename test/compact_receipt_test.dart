import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_layout.dart';
import 'combined_order_print_test.dart'
    show CapturingAdapter, CountingRepository, pdfHeight;
import 'package:cafe_and_brews/src/utils/receipt_printer.dart';
import 'package:cafe_and_brews/src/utils/printing/web_receipt_html_builder.dart';

ReceiptData espressoFixture({
  String footer = 'Visit us again soon.',
  String orderType = 'Take-out',
  String addon = 'Extra Shot',
  String payment = 'CARD',
  bool vatEnabled = false,
  bool includeKitchen = true,
}) => ReceiptData(
  orderId: 'ORDER-32',
  sequence: 32,
  orderType: orderType,
  paymentType: payment,
  cashierName: 'Jam',
  createdAt: DateTime(2026, 10, 1, 16, 50),
  storeName: 'Haven & Co.',
  storeAddress: 'Ragan Sur, Delfin Albano Isabela',
  storeContact: '',
  receiptHeader: 'Thank you for your order',
  receiptFooter: footer,
  vatEnabled: vatEnabled,
  items: [
    ReceiptItem(
      name: 'Espresso',
      quantity: 1,
      unitPrice: 89,
      lineTotal: 89,
      modifiers: [
        ReceiptModifier(name: '16 oz', isDefault: true),
        ReceiptModifier(name: 'Regular Milk', isDefault: true),
        ReceiptModifier(name: addon, priceDelta: 20),
      ],
    ),
  ],
  subtotal: 89,
  discount: 0,
  tax: vatEnabled ? 9.54 : 0,
  serviceCharge: 0,
  total: 89,
  cashReceived: payment == 'CASH' ? 100 : 0,
  change: payment == 'CASH' ? 11 : 0,
  preparationTicket: !includeKitchen
      ? null
      : PreparationTicketData(
          orderId: 'ORDER-32',
          sequence: 32,
          orderType: orderType,
          createdAt: DateTime(2026, 10, 1, 16, 50),
          items: [
            PreparationTicketItem(
              name: 'Espresso',
              quantity: 1,
              modifierLabels: ['16 oz', 'Regular Milk', addon],
            ),
          ],
        ),
);

String plainText(ReceiptData receipt, PrinterConfig config) =>
    ReceiptLayout(config)
        .combined(receipt)
        .map((line) => line.text(config.charactersPerLine))
        .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [PaperWidth.mm58, PaperWidth.mm80]) {
    test('Compact Espresso + Extra Shot acceptance on ${width.name}', () async {
      final receipt = espressoFixture();
      final config = PrinterConfig(
        paperWidth: width,
        autoCut: false,
        feedLines: 1,
      );
      final text = plainText(receipt, config);
      final html = WebReceiptHtmlBuilder.buildReceiptHtml(
        receipt,
        config: config,
      );
      final raw = utf8.decode(
        EscPosGenerator(config: config).buildReceiptBytes(receipt),
      );
      for (final output in [text, html, raw]) {
        for (final unwanted in [
          'CUT HERE',
          'END OF ORDER',
          'TOTAL DUE',
          '=====',
          'AMOUNT',
          'Subtotal',
          'Thank you for your order',
        ]) {
          expect(output, isNot(contains(unwanted)));
        }
        expect('Visit us again soon.'.allMatches(output).length, 1);
      }
      expect(text, matches(RegExp(r'1x Espresso +₱69\.00')));
      expect(text, matches(RegExp(r'Extra Shot +\+₱20\.00')));
      expect(text, matches(RegExp(r'TOTAL +₱89\.00')));
      expect(text, contains('ORDER #32 • TAKE-OUT • 4:50 PM'));
      expect(
        text,
        contains('1x ESPRESSO • 16 OZ\n   REGULAR MILK • EXTRA SHOT'),
      );
      expect(
        text.substring(0, text.indexOf('ORDER #')),
        isNot(contains('Regular Milk')),
      );
      expect(text.split('\n').last, '   REGULAR MILK • EXTRA SHOT');
      expect(
        text.split('\n').where((line) => line.startsWith('---')).length,
        2,
      );
      expect(
        text
            .split('\n')
            .every((line) => line.length <= config.charactersPerLine),
        isTrue,
      );
      expect(raw.endsWith('\x1b\x45\x00\x1b\x61\x00\x1b\x64\x01'), isTrue);
      final pdf = await PdfReceiptBuilder(
        config: config,
      ).buildPdfBytes(receipt);
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)).length,
        1,
      );
      if (width == PaperWidth.mm80) {
        final before = File('docs/receipt-layout/before.txt').readAsLinesSync();
        expect(text.split('\n').length, lessThan(before.length));
        final beforePdf = File(
          'docs/receipt-layout/before.pdf',
        ).readAsBytesSync();
        expect(pdfHeight(pdf), lessThan(pdfHeight(beforePdf)));
        if (const bool.fromEnvironment('WRITE_RECEIPT_PREVIEW')) {
          File('docs/receipt-layout/after.html').writeAsStringSync(html);
          File('docs/receipt-layout/after.txt').writeAsStringSync('$text\n');
          File('docs/receipt-layout/after.pdf').writeAsBytesSync(pdf);
        }
      }
    });
  }

  for (final width in [PaperWidth.mm58, PaperWidth.mm80]) {
    for (final payment in ['CARD', 'CASH', 'EWALLET']) {
      for (final vatEnabled in [false, true]) {
        test(
          'Payment and VAT rows: ${width.name}, $payment, VAT=$vatEnabled',
          () {
            final layout = ReceiptLayout(PrinterConfig(paperWidth: width));
            final receipt = espressoFixture(
              payment: payment,
              vatEnabled: vatEnabled,
            );
            final lines = layout.customer(receipt);
            final method = lines.singleWhere(
              (line) => line.left == 'Payment Method',
            );
            expect(method.right, payment == 'EWALLET' ? 'E-WALLET' : payment);
            expect(
              method.text(layout.columns).length,
              lessThanOrEqualTo(layout.columns),
            );
            expect(
              lines.where((line) => line.left == 'VAT Incl.').length,
              vatEnabled ? 1 : 0,
            );
            expect(lines.any((line) => line.blank), isFalse);
            if (vatEnabled) {
              expect(
                lines.singleWhere((line) => line.left == 'VAT Incl.').right,
                '₱9.54',
              );
            }
            if (payment == 'CASH') {
              expect(
                lines.singleWhere((line) => line.left == 'Cash').right,
                '₱100.00',
              );
              expect(
                lines.singleWhere((line) => line.left == 'Change').right,
                '₱11.00',
              );
            } else {
              expect(
                lines.any(
                  (line) => line.left == 'Cash' || line.left == 'Change',
                ),
                isFalse,
              );
            }
          },
        );
      }
    }
    for (final autoCut in [false, true]) {
      test(
        'Two-line manual gap, physical cut without gap: ${width.name}, autoCut=$autoCut',
        () async {
          final config = PrinterConfig(paperWidth: width, autoCut: autoCut);
          final receipt = espressoFixture();
          final layout = ReceiptLayout(config);
          final lines = layout.combined(receipt);
          final kitchenIndex = lines.indexWhere(
            (line) => line.left.startsWith('ORDER #'),
          );
          expect(lines.where((line) => line.blank).length, 2);
          expect(
            lines[kitchenIndex - 1].blank && lines[kitchenIndex - 2].blank,
            isTrue,
          );
          expect(lines[kitchenIndex - 3].left, 'Payment Method');
          final html = WebReceiptHtmlBuilder.buildReceiptHtml(
            receipt,
            config: config,
          );
          expect('class="line blank"'.allMatches(html).length, 2);
          final raw = utf8.decode(
            EscPosGenerator(config: config).buildReceiptBytes(receipt),
          );
          final plain = raw.replaceAll(
            RegExp(r'\x1b[@]|\x1b[aEd].|\x1dVB.'),
            '',
          );
          expect('\x1d\x56\x42\x00'.allMatches(raw).length, autoCut ? 2 : 0);
          expect(plain.contains('\n\n'), !autoCut);
          if (!autoCut) expect(plain, contains('CARD\n\n\nORDER #'));
          final builder = PdfReceiptBuilder(config: config);
          final combined = await builder.buildPdfBytes(receipt);
          final customer = await builder.buildPdfBytes(
            espressoFixture(includeKitchen: false),
          );
          final kitchen = await builder.buildPreparationTicketPdf(
            receipt.preparationTicket!,
          );
          final style = ThermalReceiptPdfStyle.forConfig(
            config: config,
            pageWidth: width.printableWidthMm * 72 / 25.4,
          );
          // PDF cannot embed cutter commands: it always retains the manual tear gap.
          expect(
            pdfHeight(combined) - pdfHeight(customer) - pdfHeight(kitchen),
            closeTo(2 * style.bodySize * 1.4 - style.margin.vertical, .01),
          );
        },
      );
    }
  }

  test('Empty footer has no greeting or reserved row', () {
    final layout = ReceiptLayout(const PrinterConfig());
    final empty = layout.combined(espressoFixture(footer: ''));
    final configured = layout.combined(espressoFixture());
    expect(empty.length, configured.length - 1);
    expect(
      empty.any((line) => line.left.toLowerCase().contains('thank')),
      isFalse,
    );
    expect(
      empty
          .where((line) => !line.divider && !line.blank)
          .every((line) => line.left.isNotEmpty),
      isTrue,
    );
  });

  test('58mm kitchen header shortens ORDER before wrapping', () {
    final layout = ReceiptLayout(
      const PrinterConfig(paperWidth: PaperWidth.mm58),
    );
    final lines = layout.kitchen(
      espressoFixture(orderType: 'Take-out counter').preparationTicket!,
    );
    expect(lines.first.left, '#32 • TAKE-OUT COUNTER • 4:50 PM');
  });

  test('Long modifier wraps only when needed and prints its amount once', () {
    final config = const PrinterConfig(paperWidth: PaperWidth.mm58);
    final text = plainText(
      espressoFixture(addon: 'Extra Colombian Espresso Shot With Oat Foam'),
      config,
    );
    expect(text.split('\n').every((line) => line.length <= 32), isTrue);
    expect('+₱20.00'.allMatches(text).length, 1);
    expect(text, contains('₱89.00'));
  });

  for (final quantity in [1, 2]) {
    test(
      'Checkout stores base 69 + surcharge 20 once, quantity $quantity',
      () async {
        SharedPreferences.setMockInitialValues({});
        final adapter = CapturingAdapter();
        final previous = ThermalPrinterService.instance;
        ThermalPrinterService.instance = ThermalPrinterServiceImpl(
          adapter: adapter,
        );
        addTearDown(() => ThermalPrinterService.instance = previous);
        final repository = CountingRepository();
        final controller = CoffeePosController(repository: repository);
        addTearDown(controller.dispose);
        await controller.initialize();
        controller.updateVatEnabled(false);
        const product = Product(
          id: 'espresso-69',
          name: 'Espresso',
          categoryId: 'coffee',
          price: 69,
          description: '',
          badge: '',
          modifierGroupIds: [],
        );
        controller.addProductToCart(
          product,
          quantity: quantity,
          selectedModifiers: const [
            SelectedModifier(
              groupId: 'size',
              optionId: '16oz',
              label: '16 oz',
              priceDelta: 0,
              isDefault: true,
            ),
            SelectedModifier(
              groupId: 'milk',
              optionId: 'regular',
              label: 'Regular Milk',
              priceDelta: 0,
              isDefault: true,
            ),
            SelectedModifier(
              groupId: 'addons',
              optionId: 'shot',
              label: 'Extra Shot',
              priceDelta: 20,
            ),
          ],
        );
        controller.updateCashReceived(1000);
        expect(controller.cart.single.singleItemPrice, 89);
        expect(controller.cart.single.lineTotal, 89 * quantity);
        expect(controller.checkoutSummary.total, 89 * quantity);
        final order = (await controller.checkout())!;
        expect(order.items.single.unitPrice, 89);
        expect(order.items.single.lineTotal, 89 * quantity);
        expect(order.items.single.selectedModifiers.last.priceDelta, 20);
        expect(order.total, 89 * quantity);
        final restored = OrderRecord.fromJson(order.toJson());
        expect(restored.total, order.total);
        expect(restored.items.single.selectedModifiers.last.priceDelta, 20);
        final result = await controller.printOrderPackage(restored);
        expect(result.isSuccess, isTrue);
        expect(repository.creations, 1);
        expect(adapter.submissions, 1);
        expect(adapter.receipt.total, 89 * quantity);
        final text = plainText(adapter.receipt, const PrinterConfig());
        expect(
          text,
          matches(RegExp('Espresso +₱${(69 * quantity).toStringAsFixed(2)}')),
        );
        expect(text, contains('+₱${(20 * quantity).toStringAsFixed(2)}'));
        expect(text, contains('REGULAR MILK • EXTRA SHOT'));
      },
    );
  }
}
