import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/domain/checkout_calculator.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_data.dart';
import 'package:cafe_and_brews/src/utils/printing/receipt_validator.dart';

void main() {
  group('OrderCalculationService & ReceiptValidator Integration', () {
    test('ORD-3: single 79.00 VAT-inclusive item validates with zero discrepancy', () {
      const calculator = OrderCalculationService();
      final item = CartItem(
        product: const Product(
          id: 'croissant-combo',
          name: 'Croissant Special',
          categoryId: 'snacks',
          price: 79.0,
          description: '',
          badge: '',
          modifierGroupIds: [],
        ),
        quantity: 1,
        selectedModifiers: const [],
      );

      final totals = calculator.calculate(
        cartItems: [item],
        discountAmount: 0,
        serviceChargeRate: 0,
        cashReceived: 100.0,
      );

      expect(totals.grossAmount, 79.0);
      expect(totals.vatableSales, 70.54);
      expect(totals.vatAmount, 8.46);
      expect(totals.total, 79.0);
      expect(totals.change, 21.0);

      // Convert to ReceiptData
      final receipt = ReceiptData(
        orderId: 'ORD-3',
        sequence: 3,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Cashier',
        createdAt: DateTime.now(),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '09171234567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        items: [
          ReceiptItem(
            name: item.product.name,
            quantity: item.quantity,
            unitPrice: item.singleItemPrice,
            lineTotal: item.lineTotal,
          ),
        ],
        subtotal: totals.subtotal,
        discount: totals.discount,
        tax: totals.tax,
        serviceCharge: totals.serviceCharge,
        total: totals.total,
        cashReceived: totals.cashReceived,
        change: totals.change,
        vatableSales: totals.vatableSales,
      );

      final validationError = ReceiptValidator.validate(receipt);
      expect(validationError, isNull, reason: 'ORD-3 must pass validation without expecting 87.46');
    });

    test('ORD-4: single 89.00 VAT-inclusive item validates with zero discrepancy', () {
      const calculator = OrderCalculationService();
      final item = CartItem(
        product: const Product(
          id: 'special-pastry',
          name: 'Chocolate Danish',
          categoryId: 'snacks',
          price: 89.0,
          description: '',
          badge: '',
          modifierGroupIds: [],
        ),
        quantity: 1,
        selectedModifiers: const [],
      );

      final totals = calculator.calculate(
        cartItems: [item],
        discountAmount: 0,
        serviceChargeRate: 0,
        cashReceived: 100.0,
      );

      expect(totals.grossAmount, 89.0);
      expect(totals.vatableSales, 79.46);
      expect(totals.vatAmount, 9.54);
      expect(totals.total, 89.0);
      expect(totals.change, 11.0);

      final receipt = ReceiptData(
        orderId: 'ORD-4',
        sequence: 4,
        orderType: 'Take-out',
        paymentType: 'CASH',
        cashierName: 'Cashier',
        createdAt: DateTime.now(),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '09171234567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        items: [
          ReceiptItem(
            name: item.product.name,
            quantity: item.quantity,
            unitPrice: item.singleItemPrice,
            lineTotal: item.lineTotal,
          ),
        ],
        subtotal: totals.subtotal,
        discount: totals.discount,
        tax: totals.tax,
        serviceCharge: totals.serviceCharge,
        total: totals.total,
        cashReceived: totals.cashReceived,
        change: totals.change,
        vatableSales: totals.vatableSales,
      );

      final validationError = ReceiptValidator.validate(receipt);
      expect(validationError, isNull, reason: 'ORD-4 must pass validation without expecting 98.54');
    });

    test('validates Senior Citizen 20% statutory discount correctly', () {
      const calculator = OrderCalculationService();
      final item = CartItem(
        product: const Product(
          id: 'meal',
          name: 'Breakfast Plate',
          categoryId: 'food',
          price: 200.0,
          description: '',
          badge: '',
          modifierGroupIds: [],
        ),
        quantity: 1,
        selectedModifiers: const [],
      );

      final totals = calculator.calculate(
        cartItems: [item],
        discountAmount: 0,
        serviceChargeRate: 0,
        cashReceived: 200.0,
        discountApplication: const DiscountApplication(
          type: DiscountType.seniorCitizen,
          idNumber: 'SC-12345',
          holderName: 'Juan Dela Cruz',
        ),
      );

      // 200 gross / 1.12 = 178.57 vat-exempt
      // 178.57 * 0.20 = 35.71 senior discount
      // amount due = 178.57 - 35.71 = 142.86
      expect(totals.grossAmount, 200.0);
      expect(totals.vatExemptSales, 178.57);
      expect(totals.seniorDiscount, 35.71);
      expect(totals.amountDue, 142.86);

      final receipt = ReceiptData(
        orderId: 'ORD-SC',
        sequence: 5,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Cashier',
        createdAt: DateTime.now(),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '09171234567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        items: [
          ReceiptItem(
            name: item.product.name,
            quantity: item.quantity,
            unitPrice: item.singleItemPrice,
            lineTotal: item.lineTotal,
          ),
        ],
        subtotal: totals.subtotal,
        discount: totals.discount,
        tax: totals.tax,
        serviceCharge: totals.serviceCharge,
        total: totals.total,
        cashReceived: totals.cashReceived,
        change: totals.change,
        vatExemptSales: totals.vatExemptSales,
        vatExemptionAmount: totals.vatExemptionAmount,
        seniorDiscount: totals.seniorDiscount,
      );

      final validationError = ReceiptValidator.validate(receipt);
      expect(validationError, isNull);
    });

    test('rejects tampered total with clean error message (no floating-point artifacts)', () {
      final receipt = ReceiptData(
        orderId: 'ORD-TAMPERED',
        sequence: 6,
        orderType: 'Dine In',
        paymentType: 'CASH',
        cashierName: 'Cashier',
        createdAt: DateTime.now(),
        storeName: 'Haven & Co.',
        storeAddress: '123 Coffee Lane',
        storeContact: '09171234567',
        receiptHeader: 'Official Receipt',
        receiptFooter: 'Thank you!',
        items: const [
          ReceiptItem(
            name: 'Coffee',
            quantity: 1,
            unitPrice: 79.0,
            lineTotal: 79.0,
          ),
        ],
        subtotal: 79.0,
        discount: 0.0,
        tax: 8.46,
        serviceCharge: 0.0,
        total: 99.0, // Incorrect total
        cashReceived: 100.0,
        change: 1.0,
      );

      final error = ReceiptValidator.validate(receipt);
      expect(error, isNotNull);
      expect(error, contains('expected 79.00, got 99.00'));
      expect(error, isNot(contains('.00000000')));
    });
  });
}
