import 'package:flutter/foundation.dart';

/// Immutable value object representing monetary amounts in integer minor units (cents).
///
/// Prevents IEEE 754 floating-point drift (e.g. 87.46000000000001) in financial
/// calculations, pricing, discounts, taxes, and change calculations.
@immutable
class Money implements Comparable<Money> {
  const Money(this.cents);

  /// Minor units (cents). 100 cents = ₱1.00.
  final int cents;

  /// Creates a [Money] instance from a [double] amount (e.g. 79.00 -> 7900 cents).
  factory Money.fromDouble(double amount) {
    if (!amount.isFinite) {
      return const Money(0);
    }
    return Money((amount * 100).round());
  }

  /// Creates a [Money] instance from integer cents.
  factory Money.fromCents(int cents) => Money(cents);

  /// Constant zero money value.
  static const Money zero = Money(0);

  /// Converts this [Money] to a standard [double] representation.
  double toDouble() => cents / 100.0;

  Money operator +(Money other) => Money(cents + other.cents);

  Money operator -(Money other) => Money(cents - other.cents);

  Money operator *(num multiplier) => Money((cents * multiplier).round());

  Money operator /(num divisor) {
    if (divisor == 0) {
      return const Money(0);
    }
    return Money((cents / divisor).round());
  }

  Money operator -() => Money(-cents);

  bool operator <(Money other) => cents < other.cents;

  bool operator <=(Money other) => cents <= other.cents;

  bool operator >(Money other) => cents > other.cents;

  bool operator >=(Money other) => cents >= other.cents;

  Money clamp(Money min, Money max) =>
      Money(cents.clamp(min.cents, max.cents));

  Money abs() => Money(cents.abs());

  /// Formatted amount string with exactly two decimal places and no symbol (e.g. "79.00").
  String get formattedAmount {
    final sign = cents < 0 ? '-' : '';
    final absCents = cents.abs();
    final whole = absCents ~/ 100;
    final fraction = (absCents % 100).toString().padLeft(2, '0');
    return '$sign$whole.$fraction';
  }

  /// Formatted amount with Philippine Peso symbol (e.g. "₱79.00").
  String get formattedWithSymbol => '₱$formattedAmount';

  /// Parses a string into [Money], ignoring currency symbols, commas, and whitespace.
  static Money? tryParse(String? input) {
    if (input == null) return null;
    final clean = input.replaceAll('₱', '').replaceAll('P', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(clean);
    if (parsed == null) return null;
    return Money.fromDouble(parsed);
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Money && other.cents == cents);

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => formattedWithSymbol;
}

