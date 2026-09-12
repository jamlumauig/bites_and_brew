import 'package:flutter_test/flutter_test.dart';

import 'package:cafe_and_brews/src/domain/checkout_calculator.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';

void main() {
  test(
    'checkout calculator uses vat-inclusive pricing for regular sales',
    () {
      const product = Product(
        id: 'latte',
        name: 'Signature Latte',
        categoryId: 'coffee',
        price: 145,
        description: 'Smooth espresso, steamed milk, caramel finish.',
        badge: 'Top seller',
        modifierGroupIds: <String>[],
      );
      const cartItem = CartItem(
        product: product,
        quantity: 2,
        selectedModifiers: <SelectedModifier>[
          SelectedModifier(
            groupId: 'size',
            optionId: 'large',
            label: 'Large',
            priceDelta: 32,
          ),
        ],
      );

      const calculator = CheckoutCalculator();
      final summary = calculator.summarize(
        cartItems: const [cartItem],
        discountAmount: 20,
        taxRate: 0.12,
        serviceChargeRate: 0.05,
        cashReceived: 500,
      );

      expect(summary.subtotal, 354);
      expect(summary.discount, 20);
      expect(summary.vatableSales, closeTo(298.21, 0.001));
      expect(summary.tax, closeTo(35.79, 0.001));
      expect(summary.serviceCharge, closeTo(17.7, 0.001));
      expect(summary.total, closeTo(351.7, 0.001));
      expect(summary.change, closeTo(148.3, 0.001));
      expect(summary.isValid, isTrue);
    },
  );

  test(
    'checkout calculator applies senior citizen VAT exemption and discount',
    () {
      const product = Product(
        id: 'americano',
        name: 'House Americano',
        categoryId: 'coffee',
        price: 112,
        description: 'Bright espresso with hot water and clean finish.',
        badge: 'Fast prep',
        modifierGroupIds: <String>[],
      );
      const cartItem = CartItem(
        product: product,
        quantity: 1,
        selectedModifiers: <SelectedModifier>[],
        lineId: 'line-1',
      );

      const calculator = CheckoutCalculator();
      final summary = calculator.summarize(
        cartItems: const [cartItem],
        discountAmount: 0,
        taxRate: 0.12,
        serviceChargeRate: 0,
        cashReceived: 100,
        discountApplication: const DiscountApplication(
          type: DiscountType.seniorCitizen,
          holderName: 'Juan Dela Cruz',
          idNumber: 'SEN-123',
          eligiblePersons: 1,
          eligibleLineIds: <String>['line-1'],
        ),
      );

      expect(summary.grossAmount, 112);
      expect(summary.vatExemptSales, 100);
      expect(summary.vatExemptionAmount, 12);
      expect(summary.seniorDiscount, 20);
      expect(summary.discount, 20);
      expect(summary.tax, 0);
      expect(summary.total, 80);
      expect(summary.change, 20);
      expect(summary.isValid, isTrue);
    },
  );
}
