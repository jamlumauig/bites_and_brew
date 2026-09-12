import 'coffee_pos_models.dart';

class OrderCalculationService {
  const OrderCalculationService({
    this.vatRate = 0.12,
  });

  final double vatRate;

  OrderTotals calculate({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
  }) {
    final grossAmount = _round2(
      cartItems.fold<double>(0, (sum, item) => sum + item.lineTotal),
    );
    final serviceCharge = _round2(grossAmount * serviceChargeRate);
    final effectiveDiscount = _effectiveDiscount(
      discountAmount: discountAmount,
      discountApplication: discountApplication,
    );

    final discountType = effectiveDiscount.type;
    final isStatutory =
        discountType == DiscountType.seniorCitizen ||
        discountType == DiscountType.pwd;

    double vatableSales = 0;
    double vatExemptSales = 0;
    double vatExemptionAmount = 0;
    double vatAmount = 0;
    double seniorDiscount = 0;
    double pwdDiscount = 0;
    double otherDiscount = 0;
    double amountDue = 0;

    if (isStatutory) {
      final eligibleGross = _eligibleGrossAmount(
        cartItems: cartItems,
        eligibleLineIds: effectiveDiscount.eligibleLineIds,
      );
      final eligibleBase = _vatExclusiveFromGross(
        eligibleGross,
      );
      vatExemptionAmount = _round2(eligibleGross - eligibleBase);
      final statutoryDiscount = _round2(eligibleBase * 0.20);

      seniorDiscount = discountType == DiscountType.seniorCitizen
          ? statutoryDiscount
          : 0;
      pwdDiscount = discountType == DiscountType.pwd ? statutoryDiscount : 0;

      vatExemptSales = eligibleBase;
      final regularGross = _round2(grossAmount - eligibleGross);
      vatableSales = _vatExclusiveFromGross(regularGross);
      vatAmount = _round2(regularGross - vatableSales);
      amountDue = _round2(
        grossAmount - vatExemptionAmount - statutoryDiscount + serviceCharge,
      );
    } else {
      otherDiscount = _resolveOtherDiscount(
        effectiveDiscount,
        grossAmount,
      );
      final discountedGross = _round2((grossAmount - otherDiscount).clamp(0, double.infinity));
      vatableSales = _vatExclusiveFromGross(discountedGross);
      vatAmount = _round2(discountedGross - vatableSales);
      amountDue = _round2(discountedGross + serviceCharge);
    }

    final totalDiscount = _round2(seniorDiscount + pwdDiscount + otherDiscount);
    final change = _round2((cashReceived - amountDue).clamp(0, double.infinity));
    final isValid = cartItems.isNotEmpty && amountDue > 0;

    return OrderTotals(
      grossAmount: grossAmount,
      vatableSales: vatableSales,
      vatExemptSales: vatExemptSales,
      vatExemptionAmount: vatExemptionAmount,
      vatAmount: vatAmount,
      seniorDiscount: seniorDiscount,
      pwdDiscount: pwdDiscount,
      otherDiscount: otherDiscount,
      totalDiscount: totalDiscount,
      serviceCharge: serviceCharge,
      amountDue: amountDue,
      discountApplication: effectiveDiscount,
      cashReceived: cashReceived,
      change: change,
      isValid: isValid,
    );
  }

  CheckoutSummary summarize({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double taxRate,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
  }) {
    final calculator = OrderCalculationService(vatRate: taxRate);
    final totals = calculator.calculate(
      cartItems: cartItems,
      discountAmount: discountAmount,
      serviceChargeRate: serviceChargeRate,
      cashReceived: cashReceived,
      discountApplication: discountApplication,
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

  double _resolveOtherDiscount(
    DiscountApplication application,
    double grossAmount,
  ) {
    switch (application.type) {
      case DiscountType.percentage:
        return _round2((grossAmount * application.percentage).clamp(0, grossAmount));
      case DiscountType.fixedAmount:
        return _round2(application.fixedAmount.clamp(0, grossAmount));
      case DiscountType.seniorCitizen:
      case DiscountType.pwd:
      case DiscountType.none:
        return 0;
    }
  }

  double _eligibleGrossAmount({
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
    return _round2(
      eligibleItems.fold<double>(0, (sum, item) => sum + item.lineTotal),
    );
  }

  double _vatExclusiveFromGross(double gross) {
    if (gross <= 0) {
      return 0;
    }
    return _round2(gross / (1 + vatRate));
  }

  double _round2(num value) => double.parse(value.toStringAsFixed(2));
}

class CheckoutCalculator {
  const CheckoutCalculator();

  CheckoutSummary summarize({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double taxRate,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
  }) {
    final calculator = OrderCalculationService(vatRate: taxRate);
    return calculator.summarize(
      cartItems: cartItems,
      discountAmount: discountAmount,
      taxRate: taxRate,
      serviceChargeRate: serviceChargeRate,
      cashReceived: cashReceived,
      discountApplication: discountApplication,
    );
  }

  OrderTotals calculate({
    required List<CartItem> cartItems,
    required double discountAmount,
    required double taxRate,
    required double serviceChargeRate,
    required double cashReceived,
    DiscountApplication discountApplication = const DiscountApplication.none(),
  }) {
    final calculator = OrderCalculationService(vatRate: taxRate);
    return calculator.calculate(
      cartItems: cartItems,
      discountAmount: discountAmount,
      serviceChargeRate: serviceChargeRate,
      cashReceived: cashReceived,
      discountApplication: discountApplication,
    );
  }
}

extension CheckoutSummaryDiscounts on CheckoutSummary {
  bool get hasStatutoryDiscount =>
      discountApplication.type == DiscountType.seniorCitizen ||
      discountApplication.type == DiscountType.pwd;
}
