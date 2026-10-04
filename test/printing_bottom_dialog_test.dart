import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/auto_hiding_snack_bar.dart';
import 'package:cafe_and_brews/src/ui/widgets/cashier_dashboard.dart';

OrderRecord _sampleOrder({String orderNumber = '20261002-001'}) {
  return OrderRecord(
    id: 'ORD-1',
    sequence: 1,
    orderNumber: orderNumber,
    status: OrderStatus.paid,
    orderType: 'Dine-in',
    paymentType: PaymentType.cash,
    cashierName: 'Jam',
    createdAt: DateTime(2026, 10, 2, 12, 0),
    subtotal: 100,
    discount: 0,
    tax: 0,
    serviceCharge: 0,
    total: 100,
    cashReceived: 100,
    change: 0,
    items: const [],
  );
}

void main() {
  testWidgets('showAutoHidingSnackBar auto-hides after 5s with SnackBarAction', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showAutoHidingSnackBar(
                  messenger: ScaffoldMessenger.of(context),
                  content: const Text('Order #20261002-001 saved.'),
                  action: SnackBarAction(
                    label: 'Print via Dialog',
                    onPressed: () {},
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Order #20261002-001 saved.'), findsOneWidget);
    expect(find.text('Print via Dialog'), findsOneWidget);

    // Advance 4 seconds: still visible
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(SnackBar), findsOneWidget);

    // Advance 1.5 seconds (past 5s): auto-hides cleanly
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Disposing widget tree early cleanly cancels the 5s timer with zero pending timers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showAutoHidingSnackBar(
                  messenger: ScaffoldMessenger.of(context),
                  content: const Text('Order #20261002-002 saved.'),
                  action: SnackBarAction(
                    label: 'Print via Dialog',
                    onPressed: () {},
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsOneWidget);

    // Test ends right here (only 100ms in).
    // Invariant check: '!timersPending' passes because dispose() cancelled the timer!
  });

  testWidgets('showAutoHidingSnackBar replaces prior snackbar immediately without queuing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    showAutoHidingSnackBar(
                      messenger: ScaffoldMessenger.of(context),
                      content: const Text('First SnackBar'),
                    );
                  },
                  child: const Text('First'),
                ),
                ElevatedButton(
                  onPressed: () {
                    showAutoHidingSnackBar(
                      messenger: ScaffoldMessenger.of(context),
                      content: const Text('Second SnackBar'),
                    );
                  },
                  child: const Text('Second'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('First SnackBar'), findsOneWidget);

    // Immediately trigger Second SnackBar - should replace First
    await tester.tap(find.text('Second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Second SnackBar'), findsOneWidget);

    // Advance 5.5 seconds: Second SnackBar auto-hides
    await tester.pump(const Duration(milliseconds: 5500));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('disabled auto-print shows Print action and auto-hides after 5s', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = InMemoryCoffeePosRepository();
    final controller = CoffeePosController(repository: repository);
    addTearDown(controller.dispose);

    controller.updatePrinterSettings(
      autoPrintReceipts: false,
      printerName: 'Primary Thermal',
      printerUrl: '',
    );
    final order = _sampleOrder(orderNumber: '20261002-051');

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await handlePostCheckoutPrintingForTesting(
      context: capturedContext,
      messenger: ScaffoldMessenger.of(capturedContext),
      controller: controller,
      order: order,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Saved Order #20261002-051 as a paid order.'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);

    // Advance 4s: still visible
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(SnackBar), findsOneWidget);

    // Advance 1.5s (past 5s): auto-hides
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
