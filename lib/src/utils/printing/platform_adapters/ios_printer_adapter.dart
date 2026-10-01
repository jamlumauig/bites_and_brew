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

/// iOS platform adapter supporting AirPrint, Direct Printing, System Dialog,
/// and Network ESC/POS (TCP).
class IosPrinterAdapter implements PlatformPrinterAdapter {
  const IosPrinterAdapter();

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

    // 2. Direct AirPrint (no prompt)
    if (config.transport == ThermalTransport.direct) {
      return _printDirectWithoutPrompt(
        jobId: jobId,
        receipt: receipt,
        config: config,
        pdfBytes: pdfBytes,
      );
    }

    // 3. System Print Dialog (when explicitly selected)
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

    // 2. Direct AirPrint
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

    // 3. System Dialog
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
        message: 'Unable to open iOS print sheet.',
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
        PrintLogger.warn(
          'PRINT_STATUS_UNKNOWN',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: config.printerName,
          message: 'Transmission interrupted on iOS. Duplicate print possible.',
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
        message: 'No AirPrint printer found for direct printing without prompt.',
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Printer "${config.printerName}" not found.',
      );
    }

    try {
      PrintLogger.info(
        'PRINTER_CONNECTING',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: directPrinter.name,
        message: 'Direct printing via AirPrint to ${directPrinter.name} (no sheet prompt)',
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
          message: 'AirPrint direct print succeeded without prompt',
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
          message: 'AirPrint direct print job returned false from spooler',
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
        message: 'Error communicating with AirPrint printer: $e',
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
        message: 'Opening iOS system print dialog',
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
          message: 'iOS print dialog cancelled by user.',
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
        message: 'iOS system print completed',
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
        message: 'Unable to open iOS print sheet.',
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
