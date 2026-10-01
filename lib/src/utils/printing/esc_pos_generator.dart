import 'dart:convert';
import 'dart:typed_data';
import 'preparation_ticket_data.dart';
import 'printer_config.dart';
import 'receipt_data.dart';
import 'receipt_layout.dart';

class EscPosGenerator {
  EscPosGenerator({required this.config});
  final PrinterConfig config;

  Uint8List buildReceiptBytes(ReceiptData receipt, {bool isReprint = false}) {
    final bytes = BytesBuilder(copy: false)..add(const [0x1b, 0x40]);
    if (config.openCashDrawer &&
        receipt.paymentType.toUpperCase() == 'CASH' &&
        !isReprint) {
      bytes.add(const [0x1b, 0x70, 0, 0x19, 0xfa]);
    }
    final layout = ReceiptLayout(config);
    _write(bytes, layout.customer(receipt));
    if (receipt.preparationTicket case final ticket?) {
      if (config.autoCut) {
        _finish(bytes);
      } else {
        _write(bytes, ReceiptLayout.tearGap);
      }
      _write(bytes, layout.kitchen(ticket));
    }
    _finish(bytes);
    return bytes.toBytes();
  }

  Uint8List buildPreparationTicketBytes(PreparationTicketData ticket) {
    final bytes = BytesBuilder(copy: false)..add(const [0x1b, 0x40]);
    _write(bytes, ReceiptLayout(config).kitchen(ticket));
    _finish(bytes);
    return bytes.toBytes();
  }

  void _write(BytesBuilder bytes, List<ReceiptLine> lines) {
    for (final line in lines) {
      if (line.blank) {
        bytes.addByte(0x0a);
        continue;
      }
      bytes.add([
        0x1b,
        0x61,
        line.center ? 1 : 0,
        0x1b,
        0x45,
        line.bold ? 1 : 0,
      ]);
      final text = line
          .text(config.charactersPerLine)
          .replaceAll('₱', 'P')
          .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
      bytes.add(utf8.encode('$text\n'));
    }
    bytes.add(const [0x1b, 0x45, 0, 0x1b, 0x61, 0]);
  }

  void _finish(BytesBuilder bytes) {
    // One line for the cutter, otherwise respect the configured tear-bar clearance.
    bytes.add([0x1b, 0x64, config.autoCut ? 1 : config.feedLines.clamp(1, 3)]);
    if (config.autoCut) bytes.add(const [0x1d, 0x56, 0x42, 0]);
  }
}
