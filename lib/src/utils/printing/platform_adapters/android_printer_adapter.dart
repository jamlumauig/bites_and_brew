import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../network_printer_client.dart';
import '../preparation_ticket_data.dart';
import '../print_logger.dart';
import '../print_status.dart';
import '../printer_config.dart';
import '../receipt_data.dart';
import 'platform_printer_adapter.dart';
import 'printer_resolver.dart';

/// Android platform adapter supporting Thermal Printer Apps (e.g. RawBT),
/// Android System Print Dialog, Direct Printing, and Network ESC/POS (TCP).
class AndroidPrinterAdapter implements PlatformPrinterAdapter {
  const AndroidPrinterAdapter();

  @override
  Future<PrintResult> printReceipt({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    // 1. Direct Network ESC/POS socket
    if (config.transport == ThermalTransport.networkEscPos) {
      return _printViaNetwork(
        jobId: jobId,
        receipt: receipt,
        config: config,
        escPosBytes: escPosBytes,
      );
    }

    // 2. Share to thermal printer app (e.g. RawBT / PrinterShare)
    if (config.transport == ThermalTransport.thermalApp) {
      return _printViaThermalApp(
        jobId: jobId,
        receipt: receipt,
        config: config,
        pdfBytes: pdfBytes,
      );
    }

    // 3. Direct Print (no prompt)
    if (config.transport == ThermalTransport.direct) {
      return _printDirectWithoutPrompt(
        jobId: jobId,
        receipt: receipt,
        config: config,
        pdfBytes: pdfBytes,
      );
    }

    // 4. System Print Dialog (when explicitly configured)
    return _printViaSystemDialog(
      jobId: jobId,
      receipt: receipt,
      config: config,
      pdfBytes: pdfBytes,
    );
  }

  @override
  Future<PrintResult> printPreparationTicket({
    required String jobId,
    required PreparationTicketData ticket,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    final fileName = 'PrepTicket-#${ticket.sequence}';
    final pageFormat = PdfPageFormat(
      config.paperWidth.millimeterWidth * PdfPageFormat.mm,
      double.infinity,
    );

    // 1. Direct Network ESC/POS socket
    if (config.transport == ThermalTransport.networkEscPos) {
      final endpoint = _parseEndpoint(
          config.printerUrl.isNotEmpty ? config.printerUrl : config.printerName);
      if (endpoint == null) {
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Invalid network printer address.',
        );
      }
      try {
        await sendRawBytesToNetworkPrinter(
          host: endpoint.host,
          port: endpoint.port,
          bytes: escPosBytes,
        );
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.success,
        );
      } catch (e) {
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Unable to connect to printer: $e',
        );
      }
    }

    // 2. Share to thermal printer app
    if (config.transport == ThermalTransport.thermalApp) {
      try {
        final shared = await Printing.sharePdf(
          bytes: pdfBytes,
          filename: fileName,
          subject: 'Ticket #${ticket.sequence}',
          body: 'Print this ticket using your thermal printer app.',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: shared ? PrintStatus.success : PrintStatus.canceled,
        );
      } catch (e) {
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Failed to share ticket: $e',
        );
      }
    }

    // 3. Direct Print
    if (config.transport == ThermalTransport.direct) {
      final directPrinter = await PrinterResolver.resolve(
          config.printerUrl, config.printerName);
      if (directPrinter == null) {
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Printer "${config.printerName}" not found.',
        );
      }
      try {
        final printed = await Printing.directPrintPdf(
          printer: directPrinter,
          name: fileName,
          format: pageFormat,
          forceCustomPrintPaper: true,
          onLayout: (format) async => pdfBytes,
        );
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: printed ? PrintStatus.success : PrintStatus.failedBeforeSending,
          message: printed ? null : 'Failed to send print job to ${directPrinter.name}.',
        );
      } catch (e) {
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Error communicating with printer: $e',
        );
      }
    }

    // 4. System Dialog
    try {
      final printed = await Printing.layoutPdf(
        name: fileName,
        format: pageFormat,
        dynamicLayout: false,
        onLayout: (format) async => pdfBytes,
      );
      return PrintResult(
        jobId: jobId,
        receiptId: ticket.orderId,
        status: printed ? PrintStatus.success : PrintStatus.canceled,
        message: printed ? 'System print completed' : 'Print cancelled.',
      );
    } catch (e) {
      return PrintResult(
        jobId: jobId,
        receiptId: ticket.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Unable to open system print dialog.',
      );
    }
  }

  @override
  Future<bool> isPrinterAvailable(PrinterConfig config) async {
    if (config.transport == ThermalTransport.networkEscPos) {
      final endpoint = _parseEndpoint(config.printerUrl.isNotEmpty ? config.printerUrl : config.printerName);
      if (endpoint == null) return false;
      return isNetworkPrinterReachable(host: endpoint.host, port: endpoint.port);
    }
    if (config.transport == ThermalTransport.thermalApp) {
      return true; // Android share sheet is always available
    }
    // Check system printers
    final printer = await PrinterResolver.resolve(config.printerUrl, config.printerName);
    return printer != null;
  }

  Future<PrintResult> _printViaNetwork({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List escPosBytes,
  }) async {
    final endpoint = _parseEndpoint(config.printerUrl.isNotEmpty ? config.printerUrl : config.printerName);
    if (endpoint == null) {
      PrintLogger.error(
        'PRINT_VALIDATION_FAILED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: config.printerName,
        message: 'Invalid network printer address. Please specify IP address (e.g. 192.168.1.100:9100).',
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Invalid network printer address.',
      );
    }

    var transmissionStarted = false;
    try {
      PrintLogger.info(
        'PRINTER_CONNECTING',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: '${endpoint.host}:${endpoint.port}',
        message: 'Connecting to network ESC/POS printer',
      );

      await sendRawBytesToNetworkPrinter(
        host: endpoint.host,
        port: endpoint.port,
        bytes: escPosBytes,
        onTransmissionStarted: () {
          transmissionStarted = true;
          PrintLogger.info(
            'PRINT_SENDING',
            jobId: jobId,
            receiptId: receipt.orderId,
            printer: '${endpoint.host}:${endpoint.port}',
            message: 'Sending ${escPosBytes.length} ESC/POS bytes',
          );
        },
      );

      PrintLogger.info(
        'PRINT_SUCCESS',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: config.printerName,
        message: 'Receipt sent successfully to network printer',
      );

      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.success,
      );
    } catch (e) {
      if (!transmissionStarted) {
        PrintLogger.error(
          'PRINTER_CONNECTION_FAILED',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: config.printerName,
          message: 'Unable to connect to printer at ${endpoint.host}:${endpoint.port}',
          exception: e,
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Unable to connect to printer at ${endpoint.host}:${endpoint.port}.',
        );
      } else {
        // Transmission may have partially completed
        PrintLogger.warn(
          'PRINT_STATUS_UNKNOWN',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: config.printerName,
          message: 'Transmission interrupted. Duplicate print possible.',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.unknown,
          message: 'Printing may have started. Please check the printer before reprinting.',
        );
      }
    }
  }

  Future<PrintResult> _printViaThermalApp({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
  }) async {
    final fileName = PrinterResolver.sanitizeFileName(receipt.storeName, receipt.orderId, config.printerName);
    PrintLogger.info(
      'PRINTER_CONNECTING',
      jobId: jobId,
      receiptId: receipt.orderId,
      printer: 'Thermal printer app',
      message: 'Opening Android share sheet for thermal printer app',
    );

    try {
      final shared = await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
        subject: 'Receipt ${receipt.orderId}',
        body: 'Print this receipt using your thermal printer app.',
      );

      if (!shared) {
        PrintLogger.warn(
          'PRINTER_UNAVAILABLE',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: 'Thermal printer app',
          message: 'Thermal printer app selection cancelled or unavailable.',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.canceled,
          message: 'Thermal printer app selection cancelled.',
        );
      }

      PrintLogger.info(
        'PRINT_SUCCESS',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: 'Thermal printer app',
        message: 'Receipt shared to thermal printer app',
      );

      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.success,
      );
    } catch (e, st) {
      PrintLogger.error(
        'PRINT_TRANSMISSION_FAILED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: 'Thermal printer app',
        exception: e,
        stackTrace: st,
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Failed to share receipt to thermal printer app.',
      );
    }
  }

  Future<PrintResult> _printDirectWithoutPrompt({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
  }) async {
    final fileName = PrinterResolver.sanitizeFileName(receipt.storeName, receipt.orderId, config.printerName);
    final pageFormat = PdfPageFormat(
      config.paperWidth.millimeterWidth * PdfPageFormat.mm,
      double.infinity,
    );

    final directPrinter = await PrinterResolver.resolve(config.printerUrl, config.printerName);
    if (directPrinter == null) {
      PrintLogger.error(
        'PRINTER_UNAVAILABLE',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: config.printerName,
        message: 'No printer found for direct printing without prompt.',
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Printer "${config.printerName}" not found. Please connect your thermal printer.',
      );
    }

    try {
      PrintLogger.info(
        'PRINTER_CONNECTING',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: directPrinter.name,
        message: 'Direct printing to ${directPrinter.name} (no system dialog prompt)',
      );

      final printed = await Printing.directPrintPdf(
        printer: directPrinter,
        name: fileName,
        format: pageFormat,
        forceCustomPrintPaper: true,
        onLayout: (format) async => pdfBytes,
      );

      if (printed) {
        PrintLogger.info(
          'PRINT_SUCCESS',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: directPrinter.name,
          message: 'Direct print succeeded without prompt',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.success,
        );
      } else {
        PrintLogger.error(
          'PRINT_FAILED',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: directPrinter.name,
          message: 'Direct print job returned false from OS spooler',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Failed to send print job to ${directPrinter.name}.',
        );
      }
    } catch (e, st) {
      PrintLogger.error(
        'PRINT_TRANSMISSION_FAILED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: directPrinter.name,
        exception: e,
        stackTrace: st,
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Error communicating with printer: $e',
      );
    }
  }

  Future<PrintResult> _printViaSystemDialog({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
  }) async {
    final fileName = PrinterResolver.sanitizeFileName(receipt.storeName, receipt.orderId, config.printerName);
    final pageFormat = PdfPageFormat(
      config.paperWidth.millimeterWidth * PdfPageFormat.mm,
      double.infinity,
    );

    try {
      PrintLogger.info(
        'PRINT_SENDING',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: config.printerName,
        message: 'Opening system print dialog',
      );

      final printed = await Printing.layoutPdf(
        name: fileName,
        format: pageFormat,
        dynamicLayout: false,
        onLayout: (format) async => pdfBytes,
      );

      if (!printed) {
        PrintLogger.info(
          'PRINTER_UNAVAILABLE',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: config.printerName,
          message: 'System print dialog cancelled by user.',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.canceled,
          message: 'Print cancelled.',
        );
      }

      PrintLogger.info(
        'PRINT_SUCCESS',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: config.printerName,
        message: 'System print completed',
      );

      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.success,
      );
    } catch (e, st) {
      PrintLogger.error(
        'PRINTER_CONNECTION_FAILED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: config.printerName,
        exception: e,
        stackTrace: st,
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Unable to open system print dialog.',
      );
    }
  }

  static _NetworkEndpoint? _parseEndpoint(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(':');
    final host = parts[0].trim();
    if (host.isEmpty) return null;
    var port = 9100;
    if (parts.length > 1) {
      final parsedPort = int.tryParse(parts[1].trim());
      if (parsedPort != null && parsedPort > 0 && parsedPort <= 65535) {
        port = parsedPort;
      }
    }
    return _NetworkEndpoint(host, port);
  }
}

class _NetworkEndpoint {
  const _NetworkEndpoint(this.host, this.port);
  final String host;
  final int port;
}
