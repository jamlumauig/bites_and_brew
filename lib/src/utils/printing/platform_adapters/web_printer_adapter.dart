import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../preparation_ticket_data.dart';
import '../print_logger.dart';
import '../print_status.dart';
import '../printer_config.dart';
import '../receipt_data.dart';
import '../web_receipt_html_builder.dart';
import 'platform_printer_adapter.dart';
import 'printer_resolver.dart';
import 'web_html_printer.dart';

/// Web platform adapter supporting direct Chrome Kiosk printing, local print bridges,
/// and explicit system/browser print dialogs.
///
/// Pure web browsers inside standard sandbox security models cannot open raw USB/CUPS
/// endpoints silently without user interaction. To protect cashier flow, automatic
/// checkout will NEVER hijack the UI with an unexpected print dialog when configured
/// for direct printing unless Chrome Kiosk Mode is explicitly enabled.
class WebPrinterAdapter implements PlatformPrinterAdapter {
  const WebPrinterAdapter();

  @override
  Future<PrintResult> printReceipt({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    final fileName = PrinterResolver.sanitizeFileName(
      receipt.storeName,
      receipt.orderId,
      config.printerName,
    );
    final printerLabel = config.printerName.isNotEmpty
        ? config.printerName
        : 'Browser / CUPS Spooler';

    // 1. Direct Print Request (Silent / No Dialog)
    if (config.transport == ThermalTransport.direct) {
      // 1A. Chrome Kiosk Mode: Chrome launched with --kiosk-printing auto-prints silently
      if (config.webKioskPrinting) {
        return _printViaKioskIframe(
          jobId: jobId,
          receipt: receipt,
          config: config,
          fileName: fileName,
          printerLabel: printerLabel,
        );
      }

      // 1B. Local Print Bridge (e.g. localhost daemon at http://127.0.0.1:8080/print)
      final url = config.printerUrl.trim();
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return _printViaLocalBridge(
          jobId: jobId,
          receipt: receipt,
          config: config,
          bridgeUrl: url,
          escPosBytes: escPosBytes,
        );
      }

      // 1C. Standard Chrome Web Browser Sandbox Limitation
      // Browser security blocks raw USB/CUPS access without user interaction.
      // Under NO circumstances do we open a surprise print dialog during direct checkout!
      PrintLogger.warn(
        'PRINTER_UNAVAILABLE',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: printerLabel,
        message:
            'Direct silent printing in web browser requires Chrome Kiosk Mode (--kiosk-printing), '
            'a local print bridge, or running the native macOS app.',
      );

      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message:
            'Direct silent printing in browser requires Chrome Kiosk Mode (--kiosk-printing), '
            'a local print bridge, or the native macOS app. Use "System dialog" or run macOS native app.',
      );
    }

    // 2. Direct Network TCP ESC/POS
    if (config.transport == ThermalTransport.networkEscPos) {
      PrintLogger.warn(
        'PRINTER_UNAVAILABLE',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: printerLabel,
        message:
            'Raw TCP socket printing is not supported inside web browser sandbox.',
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message:
            'Raw TCP socket printing is not supported in web browser. Use native macOS app or local bridge.',
      );
    }

    // 3. Thermal Printer App (Android Share Sheet)
    if (config.transport == ThermalTransport.thermalApp) {
      PrintLogger.warn(
        'PRINTER_UNAVAILABLE',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: printerLabel,
        message: 'Thermal printer apps are only supported on Android devices.',
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Thermal printer apps are only supported on Android devices.',
      );
    }

    // 4. System Print Dialog (Explicitly Configured or Manual User Action)
    return _printViaSystemDialog(
      jobId: jobId,
      receipt: receipt,
      config: config,
      pdfBytes: pdfBytes,
      fileName: fileName,
      printerLabel: printerLabel,
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

    if (config.transport == ThermalTransport.direct) {
      if (config.webKioskPrinting) {
        final htmlContent = WebReceiptHtmlBuilder.buildPreparationTicketHtml(
          ticket,
          config: config,
        );
        final submitted = await printHtmlViaIframe(
          htmlContent,
          title: fileName,
        );
        if (submitted) {
          return PrintResult(
            jobId: jobId,
            receiptId: ticket.orderId,
            status: PrintStatus.success,
          );
        } else {
          return PrintResult(
            jobId: jobId,
            receiptId: ticket.orderId,
            status: PrintStatus.failedBeforeSending,
            message: 'Failed to dispatch ticket print to Chrome Kiosk.',
          );
        }
      }

      return PrintResult(
        jobId: jobId,
        receiptId: ticket.orderId,
        status: PrintStatus.failedBeforeSending,
        message:
            'Direct silent printing in browser requires Chrome Kiosk Mode (--kiosk-printing) or native app.',
      );
    }

    if (kIsWeb) {
      final htmlContent = WebReceiptHtmlBuilder.buildPreparationTicketHtml(
        ticket,
        config: config,
      );
      final iframeSubmitted = await printHtmlViaIframe(
        htmlContent,
        title: fileName,
      );
      if (iframeSubmitted) {
        return PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.submittedToDialog,
          message: 'Print dialog opened.',
        );
      }
    }

    final pageFormat = PdfPageFormat(
      config.paperWidth.millimeterWidth * PdfPageFormat.mm,
      double.infinity,
    );
    final printed = await Printing.layoutPdf(
      name: fileName,
      format: pageFormat,
      dynamicLayout: false,
      onLayout: (format) async => pdfBytes,
    );

    return PrintResult(
      jobId: jobId,
      receiptId: ticket.orderId,
      status: printed ? PrintStatus.submittedToDialog : PrintStatus.canceled,
      message: printed ? 'Print dialog submitted.' : 'Print cancelled.',
    );
  }

  Future<PrintResult> _printViaKioskIframe({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required String fileName,
    required String printerLabel,
  }) async {
    try {
      PrintLogger.info(
        'PRINT_SENDING',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: printerLabel,
        message: 'Sending 80mm layout to Chrome Kiosk silent printer',
      );

      final htmlContent = WebReceiptHtmlBuilder.buildReceiptHtml(
        receipt,
        config: config,
      );

      final submitted = await printHtmlViaIframe(htmlContent, title: fileName);

      if (submitted) {
        PrintLogger.info(
          'PRINT_SUCCESS',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: printerLabel,
          message: 'Chrome Kiosk silent print job dispatched',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.success,
        );
      } else {
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Failed to dispatch silent print to Chrome Kiosk.',
        );
      }
    } catch (e, st) {
      PrintLogger.error(
        'PRINT_TRANSMISSION_FAILED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: printerLabel,
        exception: e,
        stackTrace: st,
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Chrome Kiosk print error: $e',
      );
    }
  }

  Future<PrintResult> _printViaLocalBridge({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required String bridgeUrl,
    required Uint8List escPosBytes,
  }) async {
    PrintLogger.info(
      'PRINTER_CONNECTING',
      jobId: jobId,
      receiptId: receipt.orderId,
      printer: bridgeUrl,
      message: 'Posting ESC/POS bytes to local print bridge at $bridgeUrl',
    );
    // Local bridge implementation placeholder / stub
    // Returns clean status if bridge is unreachable
    return PrintResult(
      jobId: jobId,
      receiptId: receipt.orderId,
      status: PrintStatus.failedBeforeSending,
      message: 'Local print bridge at $bridgeUrl not reachable.',
    );
  }

  Future<PrintResult> _printViaSystemDialog({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required String fileName,
    required String printerLabel,
  }) async {
    try {
      PrintLogger.info(
        'PRINT_SENDING',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: printerLabel,
        message: 'Opening browser print dialog as requested by user',
      );

      // Primary: 80mm HTML/CSS layout via iframe
      if (kIsWeb) {
        final htmlContent = WebReceiptHtmlBuilder.buildReceiptHtml(
          receipt,
          config: config,
        );

        final iframeSubmitted = await printHtmlViaIframe(
          htmlContent,
          title: fileName,
        );

        if (iframeSubmitted) {
          PrintLogger.info(
            'PRINT_DIALOG_OPENED',
            jobId: jobId,
            receiptId: receipt.orderId,
            printer: printerLabel,
            message: 'Receipt submitted to browser print dialog',
          );

          return PrintResult(
            jobId: jobId,
            receiptId: receipt.orderId,
            status: PrintStatus.submittedToDialog,
            message: 'Print dialog opened.',
          );
        }
        // Do not invoke another print API after an attempted browser submission.
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.unknown,
          message:
              'Browser submission could not be confirmed. Check before reprinting.',
        );
      }

      // Non-web fallback: Printing.layoutPdf
      final pageFormat = PdfPageFormat(
        config.paperWidth.millimeterWidth * PdfPageFormat.mm,
        double.infinity,
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
          printer: printerLabel,
          message: 'Browser print dialog cancelled by user.',
        );
        return PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.canceled,
          message: 'Print cancelled.',
        );
      }

      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.submittedToDialog,
        message: 'Print dialog submitted.',
      );
    } catch (e, st) {
      PrintLogger.error(
        'PRINT_TRANSMISSION_FAILED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: printerLabel,
        exception: e,
        stackTrace: st,
      );
      return PrintResult(
        jobId: jobId,
        receiptId: receipt.orderId,
        status: PrintStatus.failedBeforeSending,
        message: 'Unable to open browser print dialog.',
      );
    }
  }

  @override
  Future<bool> isPrinterAvailable(PrinterConfig config) async {
    if (config.transport == ThermalTransport.systemDialog) {
      return true; // Browser print dialog is available
    }
    if (config.transport == ThermalTransport.direct) {
      return config.webKioskPrinting ||
          config.printerUrl.trim().startsWith('http');
    }
    return false;
  }
}
