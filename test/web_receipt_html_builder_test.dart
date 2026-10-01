import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/utils/printing/printer_config.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';
import 'package:cafe_and_brews/src/utils/printing/web_receipt_html_builder.dart';

void main() {
  group('WebReceiptHtmlBuilder', () {
    test('generates valid 80mm HTML/CSS layout with auto height and zero margin', () {
      final receipt = ReceiptData(
        orderId: 'ORD-80MM',
        sequence: 8,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Maria',
        createdAt: DateTime(2026, 9, 22, 14, 30),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '0917-123-4567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'BIR Permit #12345',
        items: const [
          ReceiptItem(
            name: 'Spanish Latte',
            quantity: 1,
            unitPrice: 160.0,
            lineTotal: 160.0,
            modifierLabels: ['Oat Milk', 'Extra Shot'],
          ),
          ReceiptItem(
            name: 'Butter Croissant',
            quantity: 2,
            unitPrice: 78.0,
            lineTotal: 156.0,
          ),
        ],
        subtotal: 316.0,
        discount: 0.0,
        tax: 33.86,
        serviceCharge: 0.0,
        total: 316.0,
        cashReceived: 500.0,
        change: 184.0,
        vatableSales: 282.14,
      );

      const config = PrinterConfig(
        paperWidth: PaperWidth.mm80,
      );

      final html = WebReceiptHtmlBuilder.buildReceiptHtml(receipt, config: config);

      expect(html, isNotEmpty);
      expect(html, contains('size: 80mm auto;'));
      expect(html, contains('margin: 0mm;'));
      expect(html, contains('width: 80mm;'));
      expect(html, contains('Spanish Latte'));
      expect(html, contains('Butter Croissant'));
      expect(html, contains('Oat Milk'));
      expect(html, contains('Extra Shot'));
      expect(html, contains('316.00'));
      expect(html, contains('500.00'));
      expect(html, contains('184.00'));
      expect(html, contains('Vatable Sales'));
      expect(html, contains('282.14'));
      expect(html, contains('page-break-after: avoid;'));
    });
  });
}

