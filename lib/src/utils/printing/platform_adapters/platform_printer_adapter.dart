import 'dart:typed_data';

import '../preparation_ticket_data.dart';
import '../print_status.dart';
import '../printer_config.dart';
import '../receipt_data.dart';

/// Abstract adapter for platform-specific printer communication.
abstract class PlatformPrinterAdapter {
  /// Sends the prepared receipt to the target printer.
  Future<PrintResult> printReceipt({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  });

  /// Sends the prepared kitchen/barista preparation ticket to the target printer.
  Future<PrintResult> printPreparationTicket({
    required String jobId,
    required PreparationTicketData ticket,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  });

  /// Checks whether a printer is currently reachable or available under [config].
  Future<bool> isPrinterAvailable(PrinterConfig config);
}

