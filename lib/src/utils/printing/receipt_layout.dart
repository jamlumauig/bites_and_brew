import '../../domain/money.dart';
import 'preparation_ticket_data.dart';
import 'printer_config.dart';
import 'receipt_data.dart';

/// One compact content layout shared by browser, PDF and raw thermal output.
class ReceiptLine {
  const ReceiptLine(
    this.left, {
    this.right = '',
    this.bold = false,
    this.center = false,
    this.divider = false,
  });
  const ReceiptLine.separator()
    : left = '',
      right = '',
      bold = false,
      center = false,
      divider = true;
  bool get blank => !divider && left.isEmpty && right.isEmpty;

  final String left;
  final String right;
  final bool bold;
  final bool center;
  final bool divider;

  String text(int columns) => divider
      ? '-' * columns
      : right.isEmpty
      ? left
      : '$left${' ' * (columns - left.length - right.length).clamp(1, columns)}$right';
}

class ReceiptLayout {
  ReceiptLayout(this.config);
  final PrinterConfig config;
  int get columns => config.charactersPerLine;

  List<ReceiptLine> customer(ReceiptData receipt) {
    final lines = <ReceiptLine>[];
    void row(
      String left, {
      String right = '',
      bool bold = false,
      bool center = false,
    }) {
      lines.addAll(_row(left, right: right, bold: bold, center: center));
    }

    row(receipt.storeName, bold: true, center: true);
    if (validOptional(receipt.storeAddress)) {
      row(receipt.storeAddress.trim(), center: true);
    }
    if (validOptional(receipt.storeContact)) {
      row('Tel: ${receipt.storeContact.trim()}', center: true);
    }
    final header = receipt.receiptHeader.trim();
    final footer = receipt.receiptFooter.trim();
    // Greetings belong to the configured footer only; retain meaningful headers.
    if (validOptional(header) &&
        header != footer &&
        !RegExp(r'thank|visit.*again', caseSensitive: false).hasMatch(header)) {
      row(header, center: true);
    }
    if (validOptional(footer)) row(footer, center: true);
    lines.add(const ReceiptLine.separator());
    final number = receipt.sequence > 0
        ? '${receipt.sequence}'
        : receipt.orderId;
    row('Order #$number • ${receipt.orderType}');
    row(
      '${date(receipt.createdAt)}${receipt.cashierName.trim().isEmpty ? '' : ' • ${receipt.cashierName.trim()}'}',
    );
    for (final item in receipt.items) {
      final modifiers = item.modifiers
          .where((m) => !(m.isDefault && m.priceDelta.abs() < .001))
          .toList();
      // The stored line total already includes add-ons. Split it for presentation
      // only; never recalculate the transaction total in a renderer.
      final addonCents = modifiers.fold<int>(
        0,
        (sum, m) => sum + Money.fromDouble(m.priceDelta).cents * item.quantity,
      );
      final base = Money.fromCents(
        Money.fromDouble(item.lineTotal).cents - addonCents,
      );
      row('${item.quantity}x ${item.name}', right: base.formattedWithSymbol);
      for (final mod in modifiers.where((m) => m.priceDelta.abs() >= .001)) {
        final delta = Money.fromCents(
          Money.fromDouble(mod.priceDelta).cents * item.quantity,
        );
        row(
          '   ${mod.name}',
          right:
              '${delta.cents < 0 ? '-' : '+'}${delta.abs().formattedWithSymbol}',
        );
      }
      final labels = item.modifiers.isEmpty
          ? item.modifierLabels
                .where(
                  (m) => ![
                    'regular',
                    'regular milk',
                  ].contains(m.trim().toLowerCase()),
                )
                .toList()
          : modifiers
                .where((m) => m.priceDelta.abs() < .001)
                .map((m) => m.name)
                .toList();
      if (labels.isNotEmpty) row('   ${labels.join(' • ')}');
    }
    lines.add(const ReceiptLine.separator());
    if (receipt.discount > .001 || receipt.serviceCharge > .001) {
      row('Subtotal', right: money(receipt.subtotal));
    }
    if (receipt.vatEnabled && receipt.vatExemptionAmount > .001) {
      row('VAT Exemption', right: '-${money(receipt.vatExemptionAmount)}');
    }
    if (receipt.discount > .001) {
      row('Discount', right: '-${money(receipt.discount)}');
      if (receipt.seniorDiscount > .001) {
        row(
          '   Senior Citizen (20%)',
          right: '-${money(receipt.seniorDiscount)}',
        );
      }
      if (receipt.pwdDiscount > .001) {
        row('   PWD (20%)', right: '-${money(receipt.pwdDiscount)}');
      }
      if (receipt.otherDiscount > .001 &&
          receipt.otherDiscount != receipt.discount) {
        row('   Special Discount', right: '-${money(receipt.otherDiscount)}');
      }
    }
    if (receipt.serviceCharge > .001) {
      row('Service Charge', right: money(receipt.serviceCharge));
    }
    row('TOTAL', right: money(receipt.total), bold: true);
    if (receipt.vatEnabled) {
      if (receipt.tax > .001) row('VAT Incl.', right: money(receipt.tax));
      if (receipt.vatableSales > .001) {
        row('Vatable Sales', right: money(receipt.vatableSales));
      }
      if (receipt.vatExemptSales > .001) {
        row('VAT-Exempt Sales', right: money(receipt.vatExemptSales));
      }
    }
    final payment = receipt.paymentType.trim().toUpperCase();
    if (payment.isNotEmpty) {
      row('Payment Method', right: payment == 'EWALLET' ? 'E-WALLET' : payment);
    }
    if (payment == 'CASH') {
      if (receipt.cashReceived > .001) {
        row('Cash', right: money(receipt.cashReceived));
      }
      if (receipt.change > .001) row('Change', right: money(receipt.change));
    }
    return lines;
  }

  List<ReceiptLine> kitchen(PreparationTicketData ticket) {
    final lines = <ReceiptLine>[];
    final number = ticket.sequence > 0 ? '${ticket.sequence}' : ticket.orderId;
    var header =
        'ORDER #$number • ${ticket.orderType.toUpperCase()} • ${time(ticket.createdAt)}';
    if (header.length > columns) {
      header =
          '#$number • ${ticket.orderType.toUpperCase()} • ${time(ticket.createdAt)}';
    }
    lines.addAll(_row(header, bold: true));
    if (validOptional(ticket.customerName)) {
      lines.addAll(_row('Customer: ${ticket.customerName.trim()}'));
    }
    for (final item in ticket.items) {
      final mods = item.modifierLabels
          .where((m) => m.trim().isNotEmpty)
          .map((m) => m.trim().toUpperCase())
          .toList();
      final size = mods.indexWhere(
        (m) => RegExp(
          r'^(\d+\s*OZ|SMALL|MEDIUM|LARGE|TALL|GRANDE|VENTI|SOLO|SHARING)$',
        ).hasMatch(m),
      );
      var name = '${item.quantity}x ${item.name.toUpperCase()}';
      if (size >= 0 && name.length + mods[size].length + 3 <= columns) {
        name += ' • ${mods.removeAt(size)}';
      }
      lines.addAll(_row(name, bold: true));
      if (mods.isNotEmpty) lines.addAll(_row('   ${mods.join(' • ')}'));
    }
    if (validOptional(ticket.note)) {
      lines.addAll(_row('NOTE: ${ticket.note.trim()}', bold: true));
    }
    return lines;
  }

  // PDF/browser output has no embedded cutter, even when autoCut is configured.
  // Only the raw ESC/POS generator may replace this gap with a physical cut.
  static const tearGap = [ReceiptLine(''), ReceiptLine('')];

  List<ReceiptLine> combined(ReceiptData receipt) => [
    ...customer(receipt),
    if (receipt.preparationTicket case final ticket?) ...[
      ...tearGap,
      ...kitchen(ticket),
    ],
  ];

  List<ReceiptLine> _row(
    String text, {
    String right = '',
    bool bold = false,
    bool center = false,
  }) {
    final indent = text.startsWith('   ') ? '   ' : '';
    final width = (columns - (right.isEmpty ? 0 : right.length + 1)).clamp(
      4,
      columns,
    );
    final wrapped = wrap(text.trim(), width - indent.length);
    return [
      for (var i = 0; i < wrapped.length; i++)
        ReceiptLine(
          '$indent${wrapped[i]}',
          right: i == 0 ? right : '',
          bold: bold,
          center: center,
        ),
    ];
  }

  static List<String> wrap(String text, int width) {
    final result = <String>[];
    var line = '';
    for (var word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (line.isNotEmpty && line.length + word.length + 1 > width) {
        result.add(line);
        line = '';
      }
      while (word.length > width) {
        result.add(word.substring(0, width));
        word = word.substring(width);
      }
      line = line.isEmpty ? word : '$line $word';
    }
    if (line.isNotEmpty) result.add(line);
    return result;
  }

  static bool validOptional(String text) =>
      text.trim().isNotEmpty &&
      !['none', 'null', 'n/a'].contains(text.trim().toLowerCase()) &&
      !text.toLowerCase().contains('not set');
  static String money(num value) =>
      Money.fromDouble(value.toDouble()).formattedWithSymbol;
  static String time(DateTime dt) =>
      '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  static String date(DateTime dt) =>
      '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1]} ${dt.day}, ${time(dt)}';
}
