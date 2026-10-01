import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/domain/money.dart';

void main() {
  group('Money', () {
    test('creates from double and cents accurately', () {
      final m1 = Money.fromDouble(79.0);
      expect(m1.cents, 7900);
      expect(m1.toDouble(), 79.0);

      final m2 = Money.fromDouble(87.46);
      expect(m2.cents, 8746);
      expect(m2.toDouble(), 87.46);

      final m3 = Money.fromCents(1234);
      expect(m3.cents, 1234);
      expect(m3.toDouble(), 12.34);
    });

    test('formats without floating point artifacts', () {
      final m1 = Money.fromDouble(79.0);
      expect(m1.formattedAmount, '79.00');
      expect(m1.formattedWithSymbol, '₱79.00');

      final m2 = Money.fromDouble(87.46);
      expect(m2.formattedAmount, '87.46');
      expect(m2.formattedWithSymbol, '₱87.46');

      final zero = Money.zero;
      expect(zero.formattedAmount, '0.00');
      expect(zero.formattedWithSymbol, '₱0.00');

      final negative = Money.fromDouble(-5.25);
      expect(negative.formattedAmount, '-5.25');
      expect(negative.formattedWithSymbol, '₱-5.25');
    });

    test('arithmetic operations work deterministically in cents', () {
      final a = Money.fromDouble(79.0);
      final b = Money.fromDouble(21.0);

      expect((a + b).formattedAmount, '100.00');
      expect((a - b).formattedAmount, '58.00');
      expect((b * 2).formattedAmount, '42.00');
      expect((a / 2).formattedAmount, '39.50');
    });

    test('calculates VAT extraction deterministically', () {
      // 79.00 gross with 12% VAT:
      // base = 7900 * 100 / 112 = 7054 cents (70.54)
      // vat = 7900 - 7054 = 846 cents (8.46)
      final gross = Money.fromDouble(79.0);
      final base = Money((gross.cents * 100 / 112).round());
      final vat = gross - base;

      expect(base.formattedAmount, '70.54');
      expect(vat.formattedAmount, '8.46');
      expect((base + vat).formattedAmount, '79.00');
    });

    test('comparisons and clamping', () {
      final m10 = Money.fromDouble(10.0);
      final m20 = Money.fromDouble(20.0);

      expect(m10 < m20, isTrue);
      expect(m20 > m10, isTrue);
      expect(m10 == Money.fromDouble(10.0), isTrue);

      final clamped = Money.fromDouble(25.0).clamp(m10, m20);
      expect(clamped, m20);
    });

    test('tryParse handles varied currency strings', () {
      expect(Money.tryParse('₱79.00')?.cents, 7900);
      expect(Money.tryParse('P 89.50')?.cents, 8950);
      expect(Money.tryParse('1,250.75')?.cents, 125075);
      expect(Money.tryParse('invalid'), isNull);
    });
  });
}

