import 'package:flutter/foundation.dart';

/// Centralized structured logger for thermal printing events and errors.
class PrintLogger {
  const PrintLogger._();

  static void info(
    String event, {
    required String jobId,
    required String receiptId,
    String? printer,
    String? message,
  }) {
    _log('INFO', event, jobId: jobId, receiptId: receiptId, printer: printer, message: message);
  }

  static void warn(
    String event, {
    required String jobId,
    required String receiptId,
    String? printer,
    String? message,
  }) {
    _log('WARN', event, jobId: jobId, receiptId: receiptId, printer: printer, message: message);
  }

  static void error(
    String event, {
    required String jobId,
    required String receiptId,
    String? printer,
    String? message,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    final combinedMessage = [
      if (message != null && message.isNotEmpty) message,
      if (exception != null) exception.toString(),
      if (stackTrace != null) stackTrace.toString(),
    ].join(' | ');

    _log('ERROR', event, jobId: jobId, receiptId: receiptId, printer: printer, message: combinedMessage);
  }

  static void _log(
    String level,
    String event, {
    required String jobId,
    required String receiptId,
    String? printer,
    String? message,
  }) {
    final platformName = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final printerName = (printer != null && printer.trim().isNotEmpty) ? printer.trim() : 'Unknown';
    final timestamp = DateTime.now().toIso8601String();
    final detail = (message != null && message.isNotEmpty) ? ' | $message' : '';

    debugPrint(
      '$level | $event | time=$timestamp | job=$jobId | receipt=$receiptId | '
      'platform=$platformName | printer=$printerName$detail',
    );
  }
}

