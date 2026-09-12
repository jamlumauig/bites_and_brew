import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/coffee_pos_models.dart';

Future<void> printReceipt({
  required OrderRecord order,
  required String storeName,
  required String storeAddress,
  required String storeContact,
  required String receiptHeader,
  required String receiptFooter,
  required String printerName,
  required String printerUrl,
  required bool compactReceiptStyle,
}) async {
  final style = _ThermalReceiptStyle.forMode(compactReceiptStyle);
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageFormat: style.pageFormat,
      margin: style.margin,
      build: (context) => [
        _receiptHeader(
          style: style,
          storeName: storeName,
          storeAddress: storeAddress,
          storeContact: storeContact,
          receiptHeader: receiptHeader,
          printerName: printerName,
          order: order,
        ),
        pw.SizedBox(height: style.sectionGap),
        _receiptDivider(),
        pw.SizedBox(height: style.sectionGap),
        ...order.items.expand(
          (item) => _receiptItemBlock(style: style, item: item),
        ),
        pw.SizedBox(height: style.sectionGap),
        _receiptDivider(),
        pw.SizedBox(height: style.sectionGap),
        _receiptTotalRow(
          style: style,
          label: 'Subtotal',
          value: order.subtotal,
        ),
        if (order.discount.abs() > 0.001)
          _receiptTotalRow(
            style: style,
            label: 'Discount',
            value: -order.discount,
          ),
        if (order.tax.abs() > 0.001)
          _receiptTotalRow(style: style, label: 'Tax', value: order.tax),
        if (order.serviceCharge.abs() > 0.001)
          _receiptTotalRow(
            style: style,
            label: 'Service charge',
            value: order.serviceCharge,
          ),
        pw.SizedBox(height: style.rowGap),
        _receiptTotalRow(
          style: style,
          label: 'Total',
          value: order.total,
          emphasized: true,
        ),
        if (order.paymentType == PaymentType.cash) ...[
          pw.SizedBox(height: style.rowGap),
          _receiptTotalRow(
            style: style,
            label: 'Cash received',
            value: order.cashReceived,
          ),
          if (order.change.abs() > 0.001)
            _receiptTotalRow(
              style: style,
              label: 'Change',
              value: order.change,
            ),
        ],
        pw.SizedBox(height: style.sectionGap),
        _receiptFooter(style: style, receiptFooter: receiptFooter),
      ],
    ),
  );

  final bytes = await document.save();
  final printer = await _resolvePrinter(printerUrl, printerName);
  if (printer != null) {
    try {
      await Printing.directPrintPdf(
        printer: printer,
        name: _receiptFileName(storeName, order, printerName),
        format: style.pageFormat,
        forceCustomPrintPaper: true,
        onLayout: (format) async => bytes,
      );
      return;
    } catch (_) {
      // Fall back to the system print sheet if direct printing fails.
    }
  }

  await Printing.layoutPdf(
    name: _receiptFileName(storeName, order, printerName),
    onLayout: (format) async => bytes,
  );
}

Future<Printer?> _resolvePrinter(String printerUrl, String printerName) async {
  final printers = await Printing.listPrinters();
  if (printers.isEmpty) {
    return null;
  }

  final normalizedUrl = printerUrl.trim();
  if (normalizedUrl.isNotEmpty) {
    for (final printer in printers) {
      if (printer.url == normalizedUrl) {
        return printer;
      }
    }
  }

  final normalizedName = printerName.trim().toLowerCase();
  if (normalizedName.isNotEmpty) {
    for (final printer in printers) {
      final candidate = printer.name.toLowerCase();
      if (candidate == normalizedName ||
          candidate.contains(normalizedName) ||
          normalizedName.contains(candidate)) {
        return printer;
      }
    }
  }

  return null;
}

String _receiptFileName(
  String storeName,
  OrderRecord order,
  String printerName,
) {
  final storeSlug = _slugify(storeName);
  final printerSlug = _slugify(printerName);
  final orderId = order.id;
  return '$storeSlug'
      '_receipt_'
      '$orderId'
      '_'
      '$printerSlug.pdf';
}

String _slugify(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  return normalized.isEmpty
      ? 'receipt'
      : normalized.replaceAll(RegExp(r'_+'), '_');
}

pw.Widget _receiptHeader({
  required _ThermalReceiptStyle style,
  required String storeName,
  required String storeAddress,
  required String storeContact,
  required String receiptHeader,
  required String printerName,
  required OrderRecord order,
}) {
  final headerStyle = pw.TextStyle(
    fontSize: style.bodySize,
    color: PdfColors.brown900,
  );
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        storeName,
        style: headerStyle.copyWith(
          fontSize: style.titleSize,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.2,
        ),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: style.tinyGap),
      pw.Text(
        receiptHeader,
        style: headerStyle.copyWith(fontSize: style.bodySize),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: style.smallGap),
      pw.Text(
        storeAddress,
        style: headerStyle.copyWith(
          fontSize: style.smallSize,
          color: PdfColors.grey700,
        ),
        textAlign: pw.TextAlign.center,
      ),
      pw.Text(
        storeContact,
        style: headerStyle.copyWith(
          fontSize: style.smallSize,
          color: PdfColors.grey700,
        ),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: style.smallGap),
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.only(top: style.tinyGap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _receiptMetaRow('Order', order.id, style),
            _receiptMetaRow('Type', order.orderType, style),
            _receiptMetaRow(
              'Payment',
              order.paymentType.name.toUpperCase(),
              style,
            ),
            _receiptMetaRow('Cashier', order.cashierName, style),
            _receiptMetaRow('Date', _formatDate(order.createdAt), style),
            _receiptMetaRow(
              'Printer',
              printerName.isEmpty ? 'Default' : printerName,
              style,
            ),
          ],
        ),
      ),
    ],
  );
}

List<pw.Widget> _receiptItemBlock({
  required _ThermalReceiptStyle style,
  required OrderLineSnapshot item,
}) {
  final widgets = <pw.Widget>[
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            '${item.quantity}x ${item.productName}',
            style: pw.TextStyle(
              fontSize: style.bodySize,
              color: PdfColors.grey900,
            ),
          ),
        ),
        pw.SizedBox(width: style.smallGap),
        pw.Text(
          _money(item.lineTotal),
          style: pw.TextStyle(
            fontSize: style.bodySize,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
      ],
    ),
  ];

  if (item.modifierLabels.isNotEmpty) {
    widgets.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          left: style.indent,
          top: 1,
          bottom: style.rowGap,
        ),
        child: pw.Text(
          item.modifierLabels.join(', '),
          style: pw.TextStyle(
            fontSize: style.smallSize,
            color: PdfColors.grey700,
          ),
        ),
      ),
    );
  }

  return widgets;
}

pw.Widget _receiptDivider() {
  return pw.Container(height: 0.6, color: PdfColors.grey400);
}

pw.Widget _receiptTotalRow({
  required _ThermalReceiptStyle style,
  required String label,
  required double value,
  bool emphasized = false,
}) {
  final rowStyle = pw.TextStyle(
    fontSize: emphasized ? style.totalSize : style.bodySize,
    fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: PdfColors.grey900,
  );
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: style.rowGap / 2),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label, style: rowStyle)),
        pw.Text(_money(value), style: rowStyle),
      ],
    ),
  );
}

pw.Widget _receiptFooter({
  required _ThermalReceiptStyle style,
  required String receiptFooter,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        receiptFooter,
        style: pw.TextStyle(
          fontSize: style.smallSize,
          color: PdfColors.grey700,
        ),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: style.tinyGap),
      pw.Text(
        'Thank you for visiting Haven & Co.',
        style: pw.TextStyle(
          fontSize: style.smallSize,
          color: PdfColors.grey700,
        ),
        textAlign: pw.TextAlign.center,
      ),
    ],
  );
}

pw.Widget _receiptMetaRow(
  String label,
  String value,
  _ThermalReceiptStyle style,
) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: style.tinyGap / 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: style.metaLabelWidth,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: style.smallSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown800,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: style.smallSize,
              color: PdfColors.grey800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ThermalReceiptStyle {
  const _ThermalReceiptStyle({
    required this.pageFormat,
    required this.margin,
    required this.titleSize,
    required this.bodySize,
    required this.smallSize,
    required this.totalSize,
    required this.sectionGap,
    required this.rowGap,
    required this.tinyGap,
    required this.smallGap,
    required this.indent,
    required this.metaLabelWidth,
  });

  final PdfPageFormat pageFormat;
  final pw.EdgeInsets margin;
  final double titleSize;
  final double bodySize;
  final double smallSize;
  final double totalSize;
  final double sectionGap;
  final double rowGap;
  final double tinyGap;
  final double smallGap;
  final double indent;
  final double metaLabelWidth;

  factory _ThermalReceiptStyle.forMode(bool compactReceiptStyle) {
    if (compactReceiptStyle) {
      return _ThermalReceiptStyle(
        pageFormat: PdfPageFormat.roll57,
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        titleSize: 10.5,
        bodySize: 7.4,
        smallSize: 6.2,
        totalSize: 8.2,
        sectionGap: 3,
        rowGap: 1.5,
        tinyGap: 1,
        smallGap: 2,
        indent: 8,
        metaLabelWidth: 33,
      );
    }

    return _ThermalReceiptStyle(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      titleSize: 12.5,
      bodySize: 8.8,
      smallSize: 7.4,
      totalSize: 10,
      sectionGap: 4,
      rowGap: 2,
      tinyGap: 1.5,
      smallGap: 3,
      indent: 10,
      metaLabelWidth: 40,
    );
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$year-$month-$day $hour:$minute $period';
}

String _money(num value) => '₱${value.toStringAsFixed(2)}';
