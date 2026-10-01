import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'preparation_ticket_data.dart';
import 'printer_config.dart';
import 'receipt_data.dart';
import 'receipt_layout.dart';

class PdfReceiptBuilder {
  const PdfReceiptBuilder({required this.config});
  final PrinterConfig config;

  Future<Uint8List> buildPdfBytes(ReceiptData receipt) =>
      _build(ReceiptLayout(config).combined(receipt));
  Future<Uint8List> buildPreparationTicketPdf(PreparationTicketData ticket) =>
      _build(ReceiptLayout(config).kitchen(ticket));

  Future<Uint8List> _build(List<ReceiptLine> lines) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final width = config.paperWidth.printableWidthMm * PdfPageFormat.mm;
    final style = ThermalReceiptPdfStyle.forConfig(
      config: config,
      pageWidth: width,
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, double.infinity),
        margin: style.margin,
        build: (_) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            for (final line in lines)
              if (line.blank)
                pw.SizedBox(height: style.bodySize * 1.4)
              else if (line.divider)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Container(height: .5, color: PdfColors.black),
                )
              else
                pw.Row(
                  mainAxisAlignment: line.center
                      ? pw.MainAxisAlignment.center
                      : pw.MainAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Align(
                        alignment: line.center
                            ? pw.Alignment.center
                            : pw.Alignment.centerLeft,
                        child: pw.FittedBox(
                          fit: pw.BoxFit.scaleDown,
                          child: pw.Text(
                            line.left,
                            style: pw.TextStyle(
                              fontSize: style.bodySize,
                              fontWeight: line.bold
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (line.right.isNotEmpty) ...[
                      pw.SizedBox(width: 3),
                      pw.Text(
                        line.right,
                        style: pw.TextStyle(
                          fontSize: style.bodySize,
                          fontWeight: line.bold
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static double calculateReceiptHeightPoints({
    required ReceiptData receipt,
    required ThermalReceiptPdfStyle style,
    required PrinterConfig config,
  }) => _estimate(ReceiptLayout(config).combined(receipt), style);
  static double calculateTicketHeightPoints({
    required PreparationTicketData ticket,
    required ThermalReceiptPdfStyle style,
    required PrinterConfig config,
  }) => _estimate(ReceiptLayout(config).kitchen(ticket), style);
  static double _estimate(
    List<ReceiptLine> lines,
    ThermalReceiptPdfStyle style,
  ) =>
      style.margin.vertical +
      lines.fold<double>(
        0,
        (sum, line) => sum + (line.divider ? 3.5 : style.bodySize * 1.4),
      );
}

class ThermalReceiptPdfStyle {
  const ThermalReceiptPdfStyle({
    required this.pageWidth,
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

  final double pageWidth;
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

  factory ThermalReceiptPdfStyle.forConfig({
    required PrinterConfig config,
    required double pageWidth,
  }) {
    if (config.compactReceiptStyle || config.paperWidth == PaperWidth.mm58) {
      return ThermalReceiptPdfStyle(
        pageWidth: pageWidth,
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

    if (config.paperWidth == PaperWidth.mm50) {
      return ThermalReceiptPdfStyle(
        pageWidth: pageWidth,
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        titleSize: 9.5,
        bodySize: 6.5,
        smallSize: 5.6,
        totalSize: 7.5,
        sectionGap: 2.5,
        rowGap: 1.2,
        tinyGap: 0.8,
        smallGap: 1.8,
        indent: 6,
        metaLabelWidth: 28,
      );
    }

    // Default 80mm thermal roll
    return ThermalReceiptPdfStyle(
      pageWidth: pageWidth,
      margin: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      titleSize: 12.0,
      bodySize: 8.5,
      smallSize: 7.2,
      totalSize: 9.8,
      sectionGap: 3.5,
      rowGap: 1.8,
      tinyGap: 1.2,
      smallGap: 2.5,
      indent: 10,
      metaLabelWidth: 42,
    );
  }
}
