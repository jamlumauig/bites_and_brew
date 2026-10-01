import 'coffee_pos_models.dart';
import 'money.dart';

export 'money.dart';

/// Authoritative single source of truth for POS order and receipt financial calculations.
///
/// Implemented with deterministic integer minor units ([Money]) to eliminate
/// floating-point precision issues and rounding errors.
class OrderCalculationService {
  const OrderCalculationService({
    this.vatRate = 0.12,
    this.vatEnabled = true,
  });

  final double vatRate;
  final bool vatEnabled;

  OrderTotals calculate({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
    bool? vatEnabled,
  }) {
    final effectiveVatEnabled = vatEnabled ?? this.vatEnabled;
    var grossCents = 0;
    for (final item in cartItems) {
      grossCents += Money.fromDouble(item.lineTotal).cents;
    }
    final gross = Money.fromCents(grossCents);
    final serviceCharge = Money.fromDouble(gross.toDouble() * serviceChargeRate);
    final effectiveDiscount = _effectiveDiscount(
      discountAmount: discountAmount,
      discountApplication: discountApplication,
    );

    final discountType = effectiveDiscount.type;
    final isStatutory =
        discountType == DiscountType.seniorCitizen ||
        discountType == DiscountType.pwd;

    Money vatableSales = Money.zero;
    Money vatExemptSales = Money.zero;
    Money vatExemptionAmount = Money.zero;
    Money vatAmount = Money.zero;
    Money seniorDiscount = Money.zero;
    Money pwdDiscount = Money.zero;
    Money otherDiscount = Money.zero;
    Money amountDue = Money.zero;

    if (!effectiveVatEnabled) {
      if (isStatutory) {
        final eligibleGross = _eligibleGrossMoney(
          cartItems: cartItems,
          eligibleLineIds: effectiveDiscount.eligibleLineIds,
        );
        final statutoryDiscount = Money((eligibleGross.cents * 0.20).round());
        if (discountType == DiscountType.seniorCitizen) {
          seniorDiscount = statutoryDiscount;
        } else {
          pwdDiscount = statutoryDiscount;
        }
        amountDue = gross - statutoryDiscount + serviceCharge;
      } else {
        otherDiscount = _resolveOtherDiscountMoney(
          effectiveDiscount,
          gross,
        );
        final discountedGross = (gross - otherDiscount).clamp(Money.zero, gross);
        amountDue = discountedGross + serviceCharge;
      }
    } else if (isStatutory) {
      final eligibleGross = _eligibleGrossMoney(
        cartItems: cartItems,
        eligibleLineIds: effectiveDiscount.eligibleLineIds,
      );
      final eligibleBase = _vatExclusiveFromGross(eligibleGross);
      vatExemptionAmount = eligibleGross - eligibleBase;
      final statutoryDiscount = Money((eligibleBase.cents * 0.20).round());

      if (discountType == DiscountType.seniorCitizen) {
        seniorDiscount = statutoryDiscount;
      } else {
        pwdDiscount = statutoryDiscount;
      }

      vatExemptSales = eligibleBase;
      final regularGross = gross - eligibleGross;
      vatableSales = _vatExclusiveFromGross(regularGross);
      vatAmount = regularGross - vatableSales;
      amountDue = gross - vatExemptionAmount - statutoryDiscount + serviceCharge;
    } else {
      otherDiscount = _resolveOtherDiscountMoney(
        effectiveDiscount,
        gross,
      );
      final discountedGross = (gross - otherDiscount).clamp(Money.zero, gross);
      vatableSales = _vatExclusiveFromGross(discountedGross);
      vatAmount = discountedGross - vatableSales;
      amountDue = discountedGross + serviceCharge;
    }

    final totalDiscount = seniorDiscount + pwdDiscount + otherDiscount;
    final cash = Money.fromDouble(cashReceived);
    final change = (cash - amountDue).clamp(Money.zero, cash);
    final isValid = cartItems.isNotEmpty && amountDue.cents > 0;

    return OrderTotals(
      grossAmount: gross.toDouble(),
      vatableSales: vatableSales.toDouble(),
      vatExemptSales: vatExemptSales.toDouble(),
      vatExemptionAmount: vatExemptionAmount.toDouble(),
      vatAmount: vatAmount.toDouble(),
      seniorDiscount: seniorDiscount.toDouble(),
      pwdDiscount: pwdDiscount.toDouble(),
      otherDiscount: otherDiscount.toDouble(),
      totalDiscount: totalDiscount.toDouble(),
      serviceCharge: serviceCharge.toDouble(),
      amountDue: amountDue.toDouble(),
      discountApplication: effectiveDiscount,
      cashReceived: cash.toDouble(),
      change: change.toDouble(),
      isValid: isValid,
      vatEnabled: effectiveVatEnabled,
    );
  }

  CheckoutSummary summarize({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double taxRate,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
    bool vatEnabled = true,
  }) {
    final calculator = OrderCalculationService(vatRate: taxRate, vatEnabled: vatEnabled);
    final totals = calculator.calculate(
      cartItems: cartItems,
      discountAmount: discountAmount,
      serviceChargeRate: serviceChargeRate,
      cashReceived: cashReceived,
      discountApplication: discountApplication,
      vatEnabled: vatEnabled,
    );
    return CheckoutSummary(
      grossAmount: totals.grossAmount,
      vatableSales: totals.vatableSales,
      vatExemptSales: totals.vatExemptSales,
      vatExemptionAmount: totals.vatExemptionAmount,
      vatAmount: totals.vatAmount,
      seniorDiscount: totals.seniorDiscount,
      pwdDiscount: totals.pwdDiscount,
      otherDiscount: totals.otherDiscount,
      totalDiscount: totals.totalDiscount,
      serviceCharge: totals.serviceCharge,
      amountDue: totals.amountDue,
      discountApplication: totals.discountApplication,
      cashReceived: totals.cashReceived,
      change: totals.change,
      isValid: totals.isValid,
      vatEnabled: totals.vatEnabled,
    );
  }

  DiscountApplication _effectiveDiscount({
    required double discountAmount,
    required DiscountApplication discountApplication,
  }) {
    if (discountApplication.type != DiscountType.none) {
      return discountApplication;
    }
    if (discountAmount > 0) {
      return DiscountApplication(
        type: DiscountType.fixedAmount,
        fixedAmount: discountAmount,
      );
    }
    return const DiscountApplication.none();
  }

  Money _resolveOtherDiscountMoney(
    DiscountApplication application,
    Money gross,
  ) {
    switch (application.type) {
      case DiscountType.percentage:
        return Money((gross.cents * application.percentage).round()).clamp(Money.zero, gross);
      case DiscountType.fixedAmount:
        return Money.fromDouble(application.fixedAmount).clamp(Money.zero, gross);
      case DiscountType.seniorCitizen:
      case DiscountType.pwd:
      case DiscountType.none:
        return Money.zero;
    }
  }

  Money _eligibleGrossMoney({
    required List<CartItem> cartItems,
    required List<String> eligibleLineIds,
  }) {
    final selectedIds = eligibleLineIds.toSet();
    final eligibleItems = cartItems.where((item) {
      if (selectedIds.isEmpty) {
        return true;
      }
      return selectedIds.contains(item.lineId ?? item.product.id);
    });
    var sumCents = 0;
    for (final item in eligibleItems) {
      sumCents += Money.fromDouble(item.lineTotal).cents;
    }
    return Money.fromCents(sumCents);
  }

  Money _vatExclusiveFromGross(Money gross) {
    if (gross.cents <= 0) {
      return Money.zero;
    }
    final factor = 100 + (vatRate * 100).round();
    return Money((gross.cents * 100 / factor).round());
  }
}

/// Authoritative alias for [OrderCalculationService] when used in receipt pipelines.
typedef ReceiptCalculationService = OrderCalculationService;

class CheckoutCalculator {
  const CheckoutCalculator();

  CheckoutSummary summarize({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double taxRate,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
    bool vatEnabled = true,
  }) {
    final calculator = OrderCalculationService(vatRate: taxRate, vatEnabled: vatEnabled);
    return calculator.summarize(
      cartItems: cartItems,
      discountAmount: discountAmount,
      taxRate: taxRate,
      serviceChargeRate: serviceChargeRate,
      cashReceived: cashReceived,
      discountApplication: discountApplication,
      vatEnabled: vatEnabled,
    );
  }

  OrderTotals calculate({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double taxRate,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
    bool vatEnabled = true,
  }) {
    final calculator = OrderCalculationService(vatRate: taxRate, vatEnabled: vatEnabled);
    return calculator.calculate(
      cartItems: cartItems,
      discountAmount: discountAmount,
      serviceChargeRate: serviceChargeRate,
      cashReceived: cashReceived,
      discountApplication: discountApplication,
      vatEnabled: vatEnabled,
    );
  }
}

extension CheckoutSummaryDiscounts on CheckoutSummary {
  bool get hasStatutoryDiscount =>
      discountApplication.type == DiscountType.seniorCitizen ||
      discountApplication.type == DiscountType.pwd;
}
