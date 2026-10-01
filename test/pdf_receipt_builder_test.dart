import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/utils/printing/pdf_receipt_builder.dart';
import 'package:cafe_and_brews/src/utils/printing/printer_config.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfReceiptBuilder with 4 items page count check', () async {
    final receipt = ReceiptData(
      orderId: 'ORD-TEST-2',
      sequence: 2,
      orderType: 'Dine In',
      paymentType: 'CASH',
      cashierName: 'Maria',
      createdAt: DateTime(2026, 9, 26, 10, 0),
      storeName: 'Haven & Co.',
      storeAddress: '123 Coffee Lane',
      storeContact: '0917-123-4567',
      receiptHeader: 'Official Receipt',
      receiptFooter: 'BIR Permit No. 12345',
      items: const [
        ReceiptItem(
          name: 'Spanish Latte',
          quantity: 2,
          unitPrice: 160.0,
          lineTotal: 320.0,
          modifierLabels: ['Oat Milk', 'Extra Shot'],
        ),
        ReceiptItem(
          name: 'Caramel Macchiato',
          quantity: 1,
          unitPrice: 140.0,
          lineTotal: 140.0,
          modifierLabels: ['Whipped Cream', 'Vanilla Syrup'],
        ),
        ReceiptItem(
          name: 'Iced Americano',
          quantity: 1,
          unitPrice: 120.0,
          lineTotal: 120.0,
          modifierLabels: ['Less Sweet'],
        ),
        ReceiptItem(
          name: 'Croissant with Butter and Jam',
          quantity: 2,
          unitPrice: 95.0,
          lineTotal: 190.0,
        ),
      ],
      subtotal: 770.0,
      discount: 20.0,
      tax: 80.36,
      serviceCharge: 0.0,
      total: 750.0,
      cashReceived: 1000.0,
      change: 250.0,
      vatableSales: 669.64,
      vatExemptSales: 0.0,
    );

    const config = PrinterConfig(
      paperWidth: PaperWidth.mm80,
    );

    final builder = PdfReceiptBuilder(config: config);
    final pdfBytes = await builder.buildPdfBytes(receipt);

    expect(pdfBytes.isNotEmpty, isTrue);

    final pdfString = String.fromCharCodes(pdfBytes);
    final pageMatches = RegExp(r'/Type\s*/Page\b').allMatches(pdfString).length;
    final pagesMatches = RegExp(r'/Type\s*/Pages\b').allMatches(pdfString).length;
    final actualPageCount = pageMatches - pagesMatches;
    expect(actualPageCount, lessThanOrEqualTo(1));
  });
}

