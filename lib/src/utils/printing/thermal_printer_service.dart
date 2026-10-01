import 'dart:async';

import 'package:flutter/foundation.dart';

import 'esc_pos_generator.dart';
import 'pdf_receipt_builder.dart';
import 'preparation_ticket_data.dart';
import 'platform_adapters/android_printer_adapter.dart';
import 'platform_adapters/ios_printer_adapter.dart';
import 'platform_adapters/platform_printer_adapter.dart';
import 'platform_adapters/web_printer_adapter.dart';
import 'print_logger.dart';
import 'print_status.dart';
import 'printer_config.dart';
import 'receipt_data.dart';
import 'receipt_validator.dart';

/// Common service interface for cross-platform thermal receipt printing.
abstract class ThermalPrinterService {
  static ThermalPrinterService _instance = ThermalPrinterServiceImpl();

  static ThermalPrinterService get instance => _instance;

  @visibleForTesting
  static set instance(ThermalPrinterService service) {
    _instance = service;
  }

  /// Prints a validated [receipt] with optional [config] and duplicate-bypass flag.
  Future<PrintResult> printReceipt(
    ReceiptData receipt, {
    PrinterConfig? config,
    bool manualReprint = false,
  });

  /// Prints a validated barista/kitchen preparation [ticket] with optional [config].
  Future<PrintResult> printPreparationTicket(
    PreparationTicketData ticket, {
    PrinterConfig? config,
  });

  /// Checks if the configured printer is currently reachable or available.
  Future<bool> isPrinterAvailable([PrinterConfig? config]);

  /// Cancels in-flight print processing where supported.
  Future<void> cancelPrint();

  /// Recent print job history for auditing and diagnostics.
  List<PrintJobRecord> get recentJobs;
}

/// Production implementation of [ThermalPrinterService].
class ThermalPrinterServiceImpl implements ThermalPrinterService {
  ThermalPrinterServiceImpl({
    PlatformPrinterAdapter? adapter,
    PdfReceiptBuilder Function(PrinterConfig)? pdfBuilderFactory,
  }) : _adapter = adapter ?? _createPlatformAdapter(),
       _pdfBuilderFactory =
           pdfBuilderFactory ?? ((config) => PdfReceiptBuilder(config: config));

  final PdfReceiptBuilder Function(PrinterConfig) _pdfBuilderFactory;

  final PlatformPrinterAdapter _adapter;

  Future<void> _printQueue = Future<void>.value();
  final Map<String, DateTime> _recentPrints = <String, DateTime>{};
  final List<PrintJobRecord> _recentJobs = <PrintJobRecord>[];

  @override
  List<PrintJobRecord> get recentJobs => List.unmodifiable(_recentJobs);

  @override
  Future<bool> isPrinterAvailable([PrinterConfig? config]) {
    final activeConfig = config ?? const PrinterConfig();
    return _adapter.isPrinterAvailable(activeConfig);
  }

  @override
  Future<void> cancelPrint() async {
    // Queue cancellation marker
  }

  @override
  Future<PrintResult> printReceipt(
    ReceiptData receipt, {
    PrinterConfig? config,
    bool manualReprint = false,
  }) {
    final activeConfig = config ?? const PrinterConfig();
    final documentKind = receipt.preparationTicket == null
        ? 'CUSTOMER'
        : 'PACKAGE';
    final jobId = _generateJobId('${receipt.orderId}-$documentKind');
    final completer = Completer<PrintResult>();

    // Serialize all printing jobs via queue mutex to prevent corrupted output
    _printQueue = _printQueue.catchError((_) {}).then((_) async {
      PrintLogger.info(
        'PRINT_CREATED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: activeConfig.printerName,
        message: 'Print job initialized (manualReprint=$manualReprint)',
      );

      // 1. Duplicate check (15 seconds window unless manual reprint)
      final now = DateTime.now();
      final dedupeKey = '${receipt.orderId}:$documentKind';
      final lastPrintTime = _recentPrints[dedupeKey];
      if (!manualReprint &&
          lastPrintTime != null &&
          now.difference(lastPrintTime) < const Duration(seconds: 15)) {
        const message =
            'A receipt for this order is already queued or printed.';
        PrintLogger.warn(
          'DUPLICATE_PRINT_BLOCKED',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: activeConfig.printerName,
          message: message,
        );

        final result = PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.failedBeforeSending,
          message: message,
        );
        _recordJob(result, activeConfig.printerName, manualReprint);
        completer.complete(result);
        return;
      }

      if (manualReprint) {
        PrintLogger.info(
          'MANUAL_REPRINT',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: activeConfig.printerName,
          message: 'User requested manual reprint',
        );
      }

      // 2. Strict Pre-Print Validation (zero paper waste on validation errors)
      final validationError = ReceiptValidator.validate(receipt);
      if (validationError != null) {
        PrintLogger.error(
          'PRINT_VALIDATION_FAILED',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: activeConfig.printerName,
          message: validationError,
        );

        final result = PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.failedBeforeSending,
          message: validationError,
        );
        _recordJob(result, activeConfig.printerName, manualReprint);
        completer.complete(result);
        return;
      }

      PrintLogger.info(
        'PRINT_VALIDATED',
        jobId: jobId,
        receiptId: receipt.orderId,
        printer: activeConfig.printerName,
        message: 'Receipt validated successfully. Formatting in memory.',
      );

      // 3. Complete In-Memory Receipt Generation (ESC/POS & PDF)
      Uint8List escPosBytes;
      Uint8List pdfBytes;
      try {
        final generator = EscPosGenerator(config: activeConfig);
        escPosBytes = generator.buildReceiptBytes(
          receipt,
          isReprint: manualReprint,
        );

        final pdfBuilder = _pdfBuilderFactory(activeConfig);
        pdfBytes = await pdfBuilder.buildPdfBytes(receipt);

        if (escPosBytes.isEmpty || pdfBytes.isEmpty) {
          throw StateError('Generated receipt bytes are empty.');
        }
      } catch (e, st) {
        PrintLogger.error(
          'PRINT_FORMAT_FAILED',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: activeConfig.printerName,
          message: 'Failed to format receipt in memory',
          exception: e,
          stackTrace: st,
        );

        final result = PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Receipt formatting failed. No data was sent.',
        );
        _recordJob(result, activeConfig.printerName, manualReprint);
        completer.complete(result);
        return;
      }

      // 4. Transmit via Platform Adapter
      try {
        final result = await _adapter.printReceipt(
          jobId: jobId,
          receipt: receipt,
          config: activeConfig,
          pdfBytes: pdfBytes,
          escPosBytes: escPosBytes,
        );

        if (result.isSuccess) {
          _recentPrints[dedupeKey] = now;
        }

        _recordJob(result, activeConfig.printerName, manualReprint);
        completer.complete(result);
      } catch (error) {
        // Unhandled printer adapter exception -> treat as unknown to prevent double print
        PrintLogger.warn(
          'PRINT_STATUS_UNKNOWN',
          jobId: jobId,
          receiptId: receipt.orderId,
          printer: activeConfig.printerName,
          message:
              'Unhandled error during print execution. Check printer before reprinting.',
        );

        final result = PrintResult(
          jobId: jobId,
          receiptId: receipt.orderId,
          status: PrintStatus.unknown,
          message:
              'Printing may have started. Please check the printer before reprinting.',
        );
        _recordJob(result, activeConfig.printerName, manualReprint);
        completer.complete(result);
      }
    });

    return completer.future;
  }

  @override
  Future<PrintResult> printPreparationTicket(
    PreparationTicketData ticket, {
    PrinterConfig? config,
  }) {
    final activeConfig = config ?? const PrinterConfig();
    final jobId = _generateJobId('${ticket.orderId}-KITCHEN');
    final completer = Completer<PrintResult>();

    _printQueue = _printQueue.catchError((_) {}).then((_) async {
      PrintLogger.info(
        'PRINT_TICKET_CREATED',
        jobId: jobId,
        receiptId: ticket.orderId,
        printer: activeConfig.printerName,
        message:
            'Barista ticket print job initialized for Order #${ticket.sequence}',
      );

      // 1. Duplicate check (15 seconds window)
      final now = DateTime.now();
      final dedupeKey = '${ticket.orderId}:KITCHEN';
      final lastPrintTime = _recentPrints[dedupeKey];
      if (lastPrintTime != null &&
          now.difference(lastPrintTime) < const Duration(seconds: 15)) {
        const message =
            'A kitchen ticket for this order is already queued or printed.';
        PrintLogger.warn(
          'DUPLICATE_PRINT_BLOCKED',
          jobId: jobId,
          receiptId: ticket.orderId,
          printer: activeConfig.printerName,
          message: message,
        );

        final result = PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: message,
        );
        _recordJob(result, activeConfig.printerName, false);
        completer.complete(result);
        return;
      }

      if (ticket.items.isEmpty) {
        final result = PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Cannot print ticket: item list is empty.',
        );
        _recordJob(result, activeConfig.printerName, false);
        completer.complete(result);
        return;
      }

      Uint8List escPosBytes;
      Uint8List pdfBytes;
      try {
        final generator = EscPosGenerator(config: activeConfig);
        escPosBytes = generator.buildPreparationTicketBytes(ticket);

        final pdfBuilder = _pdfBuilderFactory(activeConfig);
        pdfBytes = await pdfBuilder.buildPreparationTicketPdf(ticket);

        if (escPosBytes.isEmpty || pdfBytes.isEmpty) {
          throw StateError('Generated ticket bytes are empty.');
        }
      } catch (e, st) {
        PrintLogger.error(
          'PRINT_FORMAT_FAILED',
          jobId: jobId,
          receiptId: ticket.orderId,
          printer: activeConfig.printerName,
          message: 'Failed to format preparation ticket in memory',
          exception: e,
          stackTrace: st,
        );

        final result = PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.failedBeforeSending,
          message: 'Ticket formatting failed. No data was sent.',
        );
        _recordJob(result, activeConfig.printerName, false);
        completer.complete(result);
        return;
      }

      try {
        final result = await _adapter.printPreparationTicket(
          jobId: jobId,
          ticket: ticket,
          config: activeConfig,
          pdfBytes: pdfBytes,
          escPosBytes: escPosBytes,
        );

        if (result.isSuccess) {
          _recentPrints[dedupeKey] = now;
        }

        _recordJob(result, activeConfig.printerName, false);
        completer.complete(result);
      } catch (error) {
        PrintLogger.warn(
          'PRINT_STATUS_UNKNOWN',
          jobId: jobId,
          receiptId: ticket.orderId,
          printer: activeConfig.printerName,
          message:
              'Unhandled error during ticket print execution. Check printer.',
        );

        final result = PrintResult(
          jobId: jobId,
          receiptId: ticket.orderId,
          status: PrintStatus.unknown,
          message:
              'Printing may have started. Please check the printer before reprinting.',
        );
        _recordJob(result, activeConfig.printerName, false);
        completer.complete(result);
      }
    });

    return completer.future;
  }

  void _recordJob(PrintResult result, String printer, bool manualReprint) {
    _recentJobs.insert(
      0,
      PrintJobRecord(
        jobId: result.jobId,
        receiptId: result.receiptId,
        timestamp: DateTime.now(),
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
        printer: printer,
        status: result.status,
        error: result.message,
        manualReprint: manualReprint,
      ),
    );
    if (_recentJobs.length > 50) {
      _recentJobs.removeLast();
    }
  }

  static String _generateJobId(String receiptId) {
    final now = DateTime.now().toUtc();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final time =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final cleanReceipt = receiptId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return 'PRINT-$y$m$d-$time-$cleanReceipt';
  }

  static PlatformPrinterAdapter _createPlatformAdapter() {
    if (kIsWeb) {
      return const WebPrinterAdapter();
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const AndroidPrinterAdapter(),
      TargetPlatform.iOS => const IosPrinterAdapter(),
      _ =>
        const AndroidPrinterAdapter(), // Desktop / fallback shares standard direct/system dialog behavior
    };
  }
}
