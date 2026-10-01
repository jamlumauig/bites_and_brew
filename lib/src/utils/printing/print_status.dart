import 'package:flutter/foundation.dart';

/// Lifecycle statuses for thermal print jobs.
///
/// If printing fails before bytes are sent to the printer, [failedBeforeSending]
/// is used so the user can safely retry without risking a duplicate receipt.
///
/// If a failure occurs during or after transmission has started, [unknown] is
/// used. Automatic reprints must NEVER be performed when in [unknown] state.
enum PrintStatus {
  pending,
  validating,
  connecting,
  sending,
  submittedToDialog,
  success,
  failedBeforeSending,
  unknown,
  canceled,
}

/// The result of executing a receipt print job.
@immutable
class PrintResult {
  const PrintResult({
    required this.jobId,
    required this.receiptId,
    required this.status,
    this.message,
  });

  final String jobId;
  final String receiptId;
  final PrintStatus status;
  final String? message;

  /// True if the receipt was physically confirmed (native) or submitted to the OS/browser print dialog (web).
  bool get isSuccess =>
      status == PrintStatus.success || status == PrintStatus.submittedToDialog;

  /// Returns true if it is completely safe for the user to retry the job.
  bool get canRetry =>
      status == PrintStatus.failedBeforeSending ||
      status == PrintStatus.canceled;

  @override
  String toString() =>
      'PrintResult(jobId: $jobId, receiptId: $receiptId, status: ${status.name}, message: $message)';
}

/// In-memory historical record of a print job.
@immutable
class PrintJobRecord {
  const PrintJobRecord({
    required this.jobId,
    required this.receiptId,
    required this.timestamp,
    required this.platform,
    required this.printer,
    required this.status,
    this.error,
    this.manualReprint = false,
  });

  final String jobId;
  final String receiptId;
  final DateTime timestamp;
  final String platform;
  final String printer;
  final PrintStatus status;
  final String? error;
  final bool manualReprint;

  PrintJobRecord copyWith({
    PrintStatus? status,
    String? error,
  }) {
    return PrintJobRecord(
      jobId: jobId,
      receiptId: receiptId,
      timestamp: timestamp,
      platform: platform,
      printer: printer,
      status: status ?? this.status,
      error: error ?? this.error,
      manualReprint: manualReprint,
    );
  }

  @override
  String toString() =>
      'PrintJobRecord(jobId: $jobId, receipt: $receiptId, platform: $platform, printer: $printer, status: ${status.name})';
}

