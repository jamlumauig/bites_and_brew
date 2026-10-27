import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../domain/coffee_pos_models.dart';
import '../../../utils/export_writer.dart';

class ReportsExportService {
  const ReportsExportService();

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  static String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }

  /// Exports the filtered report data as a standard CSV/Excel spreadsheet.
  Future<String> exportToCsv({
    required String periodLabel,
    required DateTime startDate,
    required DateTime endDate,
    required List<OrderRecord> orders,
    required double totalSales,
    required int totalOrders,
    required int itemsSold,
    required double avgOrderValue,
    String storeName = 'LUNAN',
  }) async {
    final buffer = StringBuffer();

    // Metadata header
    buffer.writeln('$storeName POS - Sales Report');
    buffer.writeln('Reporting Period,${_escapeCsv(periodLabel)}');
    buffer.writeln('Generated,${_escapeCsv(DateTime.now().toIso8601String())}');
    buffer.writeln('Total Sales,${totalSales.toStringAsFixed(2)}');
    buffer.writeln('Total Orders,$totalOrders');
    buffer.writeln('Average Order Value,${avgOrderValue.toStringAsFixed(2)}');
    buffer.writeln('Items Sold,$itemsSold');
    buffer.writeln();

    // Column Headers
    buffer.writeln(
      'Date,Time,Order #,Status,Order Type,Payment Method,Cashier,Category,Product,Quantity,Unit Price,Line Total',
    );

    // Data rows (itemized)
    for (final order in orders) {
      final dateStr = _formatDate(order.createdAt);
      final timeStr = _formatTime(order.createdAt);
      final orderNum = order.orderNumber;
      final status = order.status.name.toUpperCase();
      final orderType = order.orderType;
      final payment = order.paymentType.name.toUpperCase();
      final cashier = order.cashierName;

      if (order.items.isEmpty) {
        buffer.writeln(
          [
            _escapeCsv(dateStr),
            _escapeCsv(timeStr),
            _escapeCsv(orderNum),
            _escapeCsv(status),
            _escapeCsv(orderType),
            _escapeCsv(payment),
            _escapeCsv(cashier),
            'N/A',
            'No items',
            '0',
            '0.00',
            order.total.toStringAsFixed(2),
          ].join(','),
        );
      } else {
        for (final item in order.items) {
          final category = item.categoryName ?? 'Other';
          final product = item.productName;
          final qty = item.quantity;
          final unitPrice = item.unitPrice.toStringAsFixed(2);
          final lineTotal = item.lineTotal.toStringAsFixed(2);

          buffer.writeln(
            [
              _escapeCsv(dateStr),
              _escapeCsv(timeStr),
              _escapeCsv(orderNum),
              _escapeCsv(status),
              _escapeCsv(orderType),
              _escapeCsv(payment),
              _escapeCsv(cashier),
              _escapeCsv(category),
              _escapeCsv(product),
              qty.toString(),
              unitPrice,
              lineTotal,
            ].join(','),
          );
        }
      }
    }

    final startFileStr = _formatDate(startDate);
    final endFileStr = _formatDate(endDate);
    final fileName = 'pos_sales_report_${startFileStr}_to_$endFileStr.csv';

    return saveTextToDownloads(
      text: buffer.toString(),
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// Builds a PDF document representation of the analytics report.
  Future<Uint8List> buildPdfBytes({
    required String periodLabel,
    required DateTime startDate,
    required DateTime endDate,
    required List<OrderRecord> orders,
    required double totalSales,
    required int totalOrders,
    required int itemsSold,
    required double avgOrderValue,
    required Map<String, double> categorySales,
    required List<MapEntry<String, int>> topProducts,
    String storeName = 'LUNAN',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    storeName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#4A2E18'),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'SALES & ANALYTICS REPORT',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#E87852'),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Period: ${periodLabel.replaceAll('–', '-').replaceAll('—', '-')}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Generated: ${_formatDate(DateTime.now())} ${_formatTime(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1, color: PdfColor.fromHex('#EADBCE')),
          pw.SizedBox(height: 8),

          // KPI Summary Cards
          pw.Row(
            children: [
              _pdfKpiCard('Total Sales', 'PHP ${totalSales.toStringAsFixed(2)}'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Total Orders', '$totalOrders'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Average Order', 'PHP ${avgOrderValue.toStringAsFixed(2)}'),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Items Sold', '$itemsSold'),
            ],
          ),
          pw.SizedBox(height: 16),

          // Side-by-side Categories and Top Products
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Categories
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Sales by Category',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#4A2E18'),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColor.fromHex('#F0E6DE'),
                        width: 0.5,
                      ),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#FBF8F4'),
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Category',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Sales',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                '% Share',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        ...categorySales.entries.map((entry) {
                          final pct = totalSales > 0
                              ? ((entry.value / totalSales) * 100).toStringAsFixed(1)
                              : '0.0';
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 8)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  'PHP ${entry.value.toStringAsFixed(2)}',
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  '$pct%',
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              // Top Products
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Top Products',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#4A2E18'),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColor.fromHex('#F0E6DE'),
                        width: 0.5,
                      ),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#FBF8F4'),
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                '#',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Product',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Qty',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        ...topProducts.take(8).toList().asMap().entries.map((item) {
                          final rank = item.key + 1;
                          final entry = item.value;
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('$rank', style: const pw.TextStyle(fontSize: 8)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 8)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  '${entry.value}',
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Orders Summary Table
          pw.Text(
            'Order History Log (${orders.length} orders)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#4A2E18'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#F0E6DE'),
              width: 0.5,
            ),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FBF8F4'),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Date/Time', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Order #', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Status', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Type', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Pay', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Items', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...orders.take(100).map((order) {
                final dateStr = '${_formatDate(order.createdAt)} ${_formatTime(order.createdAt)}';
                final itemsCount = order.items.fold<int>(0, (s, i) => s + i.quantity);
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(order.orderNumber, style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(order.status.name.toUpperCase(), style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(order.orderType, style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(order.paymentType.name.toUpperCase(), style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('$itemsCount', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('PHP ${order.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7)),
                    ),
                  ],
                );
              }),
            ],
          ),
          if (orders.length > 100) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Showing first 100 orders in print summary. Download CSV for the full data.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfKpiCard(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#FBF8F4'),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromHex('#EADBCE'), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4A2E18')),
            ),
          ],
        ),
      ),
    );
  }

  /// Downloads the PDF report.
  Future<String> exportToPdf({
    required String periodLabel,
    required DateTime startDate,
    required DateTime endDate,
    required List<OrderRecord> orders,
    required double totalSales,
    required int totalOrders,
    required int itemsSold,
    required double avgOrderValue,
    required Map<String, double> categorySales,
    required List<MapEntry<String, int>> topProducts,
    String storeName = 'LUNAN',
  }) async {
    final bytes = await buildPdfBytes(
      periodLabel: periodLabel,
      startDate: startDate,
      endDate: endDate,
      orders: orders,
      totalSales: totalSales,
      totalOrders: totalOrders,
      itemsSold: itemsSold,
      avgOrderValue: avgOrderValue,
      categorySales: categorySales,
      topProducts: topProducts,
      storeName: storeName,
    );

    final startFileStr = _formatDate(startDate);
    final endFileStr = _formatDate(endDate);
    final fileName = 'pos_sales_report_${startFileStr}_to_$endFileStr.pdf';

    return saveBytesToDownloads(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }

  /// Directly sends the PDF report to the printer / print dialog.
  Future<bool> printReport({
    required String periodLabel,
    required DateTime startDate,
    required DateTime endDate,
    required List<OrderRecord> orders,
    required double totalSales,
    required int totalOrders,
    required int itemsSold,
    required double avgOrderValue,
    required Map<String, double> categorySales,
    required List<MapEntry<String, int>> topProducts,
    String storeName = 'LUNAN',
  }) async {
    final bytes = await buildPdfBytes(
      periodLabel: periodLabel,
      startDate: startDate,
      endDate: endDate,
      orders: orders,
      totalSales: totalSales,
      totalOrders: totalOrders,
      itemsSold: itemsSold,
      avgOrderValue: avgOrderValue,
      categorySales: categorySales,
      topProducts: topProducts,
      storeName: storeName,
    );

    return Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'POS-Sales-Report',
    );
  }
}
