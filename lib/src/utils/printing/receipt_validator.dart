import '../../domain/money.dart';
import 'receipt_data.dart';

/// Validates receipt data and mathematical calculations before any printer
/// commands are formulated or transmitted.
///
/// Supports both VAT-inclusive pricing (standard Philippine retail model, where
/// tax is extracted from gross amounts) and VAT-exclusive pricing (where tax is
/// added on top), eliminating false validation failures and floating-point noise.
class ReceiptValidator {
  const ReceiptValidator._();

  static const _errorPatterns = [
    'exception:',
    'error:',
    'stack trace:',
    'traceback (most recent call last)',
    '500 internal',
    '<!doctype',
    '{"error":',
    'nullpointerexception',
    'typeerror:',
  ];

  static bool _containsErrorOrDiagnosticText(String text) {
    final lower = text.toLowerCase();
    for (final pattern in _errorPatterns) {
      if (lower.contains(pattern)) return true;
    }
    // Reject abnormal unprintable control bytes (excluding \t, \n, \r)
    if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(text)) {
      return true;
    }
    return false;
  }

  /// Validates [receipt]. Returns `null` if valid, or a descriptive reason string
  /// if invalid.
  static String? validate(ReceiptData receipt) {
    final ticket = receipt.preparationTicket;
    if (ticket != null) {
      if (ticket.orderId != receipt.orderId ||
          ticket.sequence != receipt.sequence ||
          ticket.items.isEmpty ||
          ticket.items.length != receipt.items.length) {
        return 'Invalid kitchen ticket for this order.';
      }
      final text = [ticket.orderType, ticket.customerName, ticket.note];
      for (var i = 0; i < ticket.items.length; i++) {
        final item = ticket.items[i];
        if (item.name.trim().isEmpty ||
            item.quantity <= 0 ||
            item.name != receipt.items[i].name ||
            item.quantity != receipt.items[i].quantity) {
          return 'Invalid kitchen item for this order.';
        }
        text.addAll([item.name, ...item.modifierLabels]);
      }
      if (text.any(_containsErrorOrDiagnosticText)) {
        return 'Kitchen ticket contains diagnostic/error payload. Printing aborted.';
      }
    }
    if (receipt.orderId.trim().isEmpty) {
      return 'Missing receipt ID.';
    }
    if (receipt.storeName.trim().isEmpty) {
      return 'Missing store name.';
    }
    if (receipt.items.isEmpty) {
      return 'Receipt has no items.';
    }

    // Never print error or diagnostic payload strings
    if (_containsErrorOrDiagnosticText(receipt.orderId) ||
        _containsErrorOrDiagnosticText(receipt.storeName) ||
        _containsErrorOrDiagnosticText(receipt.receiptHeader) ||
        _containsErrorOrDiagnosticText(receipt.receiptFooter) ||
        _containsErrorOrDiagnosticText(receipt.cashierName) ||
        _containsErrorOrDiagnosticText(receipt.orderType)) {
      return 'Receipt contains diagnostic/error payload. Printing aborted.';
    }

    for (final item in receipt.items) {
      if (_containsErrorOrDiagnosticText(item.name)) {
        return 'Receipt item ${item.name} contains diagnostic/error payload. Printing aborted.';
      }
      for (final mod in item.modifierLabels) {
        if (_containsErrorOrDiagnosticText(mod)) {
          return 'Receipt modifier contains diagnostic/error payload. Printing aborted.';
        }
      }
    }

    var itemsSumCents = 0;
    for (final item in receipt.items) {
      if (item.name.trim().isEmpty) {
        return 'Receipt item missing product name.';
      }
      if (item.quantity <= 0) {
        return 'Receipt item ${item.name} quantity must be greater than zero.';
      }
      if (!item.unitPrice.isFinite || item.unitPrice < 0) {
        return 'Receipt item ${item.name} unit price is invalid.';
      }
      if (!item.lineTotal.isFinite || item.lineTotal < 0) {
        return 'Receipt item ${item.name} line total is invalid.';
      }
      itemsSumCents += Money.fromDouble(item.lineTotal).cents;
    }

    if (!receipt.subtotal.isFinite || receipt.subtotal < 0) {
      return 'Receipt subtotal is invalid.';
    }

    final itemsSum = Money.fromCents(itemsSumCents);
    final subtotal = Money.fromDouble(receipt.subtotal);

    // Delta allowance of 5 cents for penny rounding across multiple line items
    if ((itemsSum - subtotal).abs().cents > 5) {
      return 'Receipt subtotal does not match item totals sum (expected ${itemsSum.formattedAmount}, got ${subtotal.formattedAmount}).';
    }

    if (!receipt.discount.isFinite || receipt.discount < 0) {
      return 'Receipt discount is invalid.';
    }
    if (!receipt.tax.isFinite || receipt.tax < 0) {
      return 'Receipt tax is invalid.';
    }
    if (!receipt.serviceCharge.isFinite || receipt.serviceCharge < 0) {
      return 'Receipt service charge is invalid.';
    }
    if (!receipt.total.isFinite || receipt.total < 0) {
      return 'Receipt total is invalid.';
    }

    final discount = Money.fromDouble(receipt.discount);
    final vatExemption = Money.fromDouble(receipt.vatExemptionAmount);
    final tax = Money.fromDouble(receipt.tax);
    final serviceCharge = Money.fromDouble(receipt.serviceCharge);
    final total = Money.fromDouble(receipt.total);

    // 1. VAT-Inclusive calculation (retail standard: total = subtotal - vatExemption - discount + serviceCharge)
    final inclusiveTotal = (subtotal - vatExemption - discount + serviceCharge)
        .clamp(Money.zero, subtotal + serviceCharge);

    // 2. VAT-Exclusive calculation (fallback: total = subtotal - discount + tax + serviceCharge)
    final exclusiveTotal = (subtotal - discount + tax + serviceCharge).clamp(
      Money.zero,
      subtotal + tax + serviceCharge,
    );

    final isInclusiveMatch = (total - inclusiveTotal).abs().cents <= 5;
    final isExclusiveMatch = (total - exclusiveTotal).abs().cents <= 5;

    if (!isInclusiveMatch && !isExclusiveMatch) {
      return 'Receipt total does not match calculations (expected ${inclusiveTotal.formattedAmount}, got ${total.formattedAmount}).';
    }

    if (receipt.paymentType.toUpperCase() == 'CASH') {
      if (!receipt.cashReceived.isFinite) {
        return 'Cash received is invalid.';
      }
      final cashReceived = Money.fromDouble(receipt.cashReceived);
      if (cashReceived.cents < (total.cents - 1)) {
        return 'Cash received is less than receipt total.';
      }
      if (!receipt.change.isFinite || receipt.change < 0) {
        return 'Change calculation is invalid.';
      }
      final computedChange = (cashReceived - total).clamp(
        Money.zero,
        cashReceived,
      );
      final change = Money.fromDouble(receipt.change);
      if ((computedChange - change).abs().cents > 5) {
        return 'Change calculation mismatch (expected ${computedChange.formattedAmount}, got ${change.formattedAmount}).';
      }
    }

    return null;
  }
}
