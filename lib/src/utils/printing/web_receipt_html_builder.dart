import 'preparation_ticket_data.dart';
import 'printer_config.dart';
import 'receipt_data.dart';
import 'receipt_layout.dart';

class WebReceiptHtmlBuilder {
  const WebReceiptHtmlBuilder._();

  static String buildReceiptHtml(
    ReceiptData receipt, {
    PrinterConfig config = const PrinterConfig(),
  }) => _document(
    ReceiptLayout(config).combined(receipt),
    config,
    'Receipt - ${receipt.orderId}',
  );

  static String buildPreparationTicketHtml(
    PreparationTicketData ticket, {
    PrinterConfig config = const PrinterConfig(),
  }) => _document(
    ReceiptLayout(config).kitchen(ticket),
    config,
    'Prep Ticket - #${ticket.sequence}',
  );

  static String _document(
    List<ReceiptLine> lines,
    PrinterConfig config,
    String title,
  ) {
    final width = config.paperWidth.millimeterWidth;
    final printable = config.paperWidth.printableWidthMm;
    final fontSize = printable * 96 / 25.4 / (config.charactersPerLine * .6);
    final body = lines
        .map(
          (line) => line.blank
              ? '<div class="line blank" aria-hidden="true"></div>'
              : line.divider
              ? '<div class="divider"></div>'
              : '<div class="line${line.bold ? ' bold' : ''}${line.center ? ' center' : ''}">${_escape(line.text(config.charactersPerLine))}</div>',
        )
        .join('\n');
    return '''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>${_escape(title)}</title>
<style>
@page { size: ${width}mm auto; margin: 0mm; }
html, body { width: ${width}mm; margin: 0; padding: 0; color: #000; background: #fff; }
.receipt-wrapper { width: ${printable}mm; margin: 0 auto; padding: 1mm 0; page-break-after: avoid; }
.line { font-family: 'Courier New', monospace; font-size: ${fontSize}px; line-height: 1.15; white-space: pre; }
.blank { height: 1.15em; }
.bold { font-weight: bold; } .center { text-align: center; }
.divider { border-top: .5px dashed #000; margin: 2px 0; }
</style></head><body><div class="receipt-wrapper">
$body
</div></body></html>''';
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
}
