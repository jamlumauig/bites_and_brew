import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/discount_settings_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CoffeePosController createController() =>
      CoffeePosController(repository: InMemoryCoffeePosRepository());
  const employee = DiscountOption(
    id: 'employee',
    name: 'Employee',
    type: DiscountType.percentage,
    value: 10,
  );

  test(
    'percentage applies correctly, survives export, and is stored on the order',
    () async {
      final controller = createController();
      await controller.initialize();
      controller.updatePrinterSettings(printerName: 'Test', printerUrl: '', autoPrintReceipts: false);
      controller.updateDiscountSettings(enabled: true, options: [employee]);
      controller.addProductToCart(controller.products.first, quantity: 1);
      controller.selectDiscount('employee');
      final summary = controller.checkoutSummary;
      expect(summary.discount, closeTo(summary.grossAmount * .1, .01));
      final restored = createController();
      restored.importStateJson(controller.exportStateJson());
      expect(restored.selectedDiscountId, 'employee');
      expect(restored.checkoutSummary.total, summary.total);
      final order = await controller.checkout();
      expect(order, isNotNull);
      expect(order!.discount, summary.discount);
      expect(order.discountApplication.label, 'Employee');
      expect(controller.selectedDiscountId, isNull);
      controller.dispose();
      restored.dispose();
    },
  );

  test(
    'disabling a type or all discounts clears selection without changing historical settings',
    () async {
      final controller = createController();
      await controller.initialize();
      controller.addProductToCart(controller.products.first, quantity: 1);
      controller.updateDiscountSettings(enabled: true, options: [employee]);
      controller.selectDiscount('employee');
      controller.updateDiscountSettings(
        enabled: true,
        options: [employee.copyWith(enabled: false)],
      );
      expect(controller.selectedDiscountId, isNull);
      expect(controller.checkoutSummary.discount, 0);
      controller.selectDiscount('employee');
      expect(controller.selectedDiscountId, isNull);
      controller.updateDiscountSettings(enabled: true, options: [employee]);
      controller.selectDiscount('employee');
      controller.updateDiscountSettings(enabled: false, options: [employee]);
      expect(controller.availableDiscounts, isEmpty);
      expect(controller.checkoutSummary.discount, 0);
      expect(controller.discountOptions.single.name, 'Employee');
      controller.dispose();
    },
  );

  test(
    'fixed discounts clamp to subtotal and Senior/PWD retain existing calculations',
    () async {
      final controller = createController();
      await controller.initialize();
      controller.addProductToCart(controller.products.first, quantity: 1);
      controller.updateDiscountSettings(
        enabled: true,
        options: [
          ...DiscountOption.defaults,
          const DiscountOption(
            id: 'free',
            name: 'Promotion',
            type: DiscountType.fixedAmount,
            value: 99999,
          ),
        ],
      );
      controller.selectDiscount('free');
      expect(controller.checkoutSummary.total, 0);
      controller.selectDiscount('senior');
      expect(controller.checkoutSummary.seniorDiscount, greaterThan(0));
      expect(controller.checkoutSummary.pwdDiscount, 0);
      controller.selectDiscount('pwd');
      expect(controller.checkoutSummary.pwdDiscount, greaterThan(0));
      expect(controller.checkoutSummary.seniorDiscount, 0);
      controller.dispose();
    },
  );

  test('invalid percentages and duplicate names are rejected', () {
    final controller = createController();
    for (final value in [-1.0, 0.0, 101.0, double.nan, double.infinity]) {
      expect(
        () => controller.updateDiscountSettings(
          enabled: true,
          options: [employee.copyWith(value: value)],
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => controller.updateDiscountSettings(
        enabled: true,
        options: [
          employee,
          const DiscountOption(
            id: 'duplicate',
            name: ' employee ',
            type: DiscountType.fixedAmount,
            value: 5,
          ),
        ],
      ),
      throwsArgumentError,
    );
    controller.dispose();
  });

  testWidgets('settings add and save a named custom discount', (tester) async {
    final controller = createController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DiscountSettingsDialog(controller: controller)),
      ),
    );
    await tester.tap(find.text('Enable discounts'));
    await tester.tap(find.text('Add discount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Student');
    await tester.enterText(find.byType(TextFormField).last, '15');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.discountsEnabled, isTrue);
    expect(controller.availableDiscounts.last.name, 'Student');
    expect(controller.availableDiscounts.last.value, 15);
    controller.dispose();
  });
}
