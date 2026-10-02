import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/ui/widgets/order_status_dialog.dart';

void main() {
  for (final action in [OrderAction.cancel, OrderAction.refund]) {
    testWidgets(
      '$action requires confirmation and reason, prevents repeated submission',
      (tester) async {
        var calls = 0;
        String? reason;
        final saved = Completer<bool>();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => OrderStatusDialog(
                      action: action,
                      orderNumber: 83,
                      amount: 350,
                      onConfirm: (value) {
                        calls++;
                        reason = value;
                        return saved.future;
                      },
                    ),
                  ),
                  child: const Text('Action'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Action'));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.textContaining('#83'), findsOneWidget);
        expect(find.textContaining('₱350.00'), findsOneWidget);
        final confirm = action == OrderAction.refund
            ? 'Confirm Full Refund'
            : 'Confirm Cancellation';
        if (action == OrderAction.refund) {
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, confirm),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pump();
        }
        await tester.tap(find.text(confirm));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.text('Enter a reason.'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField),
          'Customer changed their mind',
        );
        await tester.tap(find.text(confirm));
        await tester.pump();
        expect(calls, 1);
        expect(reason, 'Customer changed their mind');
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        saved.complete(true);
        await tester.pumpAndSettle();
        expect(find.byType(OrderStatusDialog), findsNothing);
      },
    );

    testWidgets('$action dismisses without modifying order', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => OrderStatusDialog(
                    action: action,
                    orderNumber: 83,
                    amount: 350,
                    onConfirm: (_) async {
                      calls++;
                      return true;
                    },
                  ),
                ),
                child: const Text('Action'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(OrderStatusDialog), findsNothing);
    });
  }
  testWidgets('save failure keeps dialog open with reason and error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderStatusDialog(
          action: OrderAction.cancel,
          orderNumber: 83,
          amount: 350,
          onConfirm: (_) async => throw StateError('Already refunded'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Wrong order');
    await tester.tap(find.text('Confirm Cancellation'));
    await tester.pumpAndSettle();
    expect(find.text('Already refunded'), findsOneWidget);
    expect(find.text('Wrong order'), findsOneWidget);
    expect(find.byType(OrderStatusDialog), findsOneWidget);
  });
}
