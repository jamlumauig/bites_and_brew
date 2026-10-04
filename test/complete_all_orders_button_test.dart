import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/ui/widgets/complete_all_orders_button.dart';

OrderQueueRecord queue(int number) => OrderQueueRecord(
  id: 'Q-$number',
  sequence: number,
  status: OrderQueueStatus.preparing,
  customerName: '',
  orderType: 'Dine-in',
  createdAt: DateTime(2026),
  items: [],
);

void main() {
  testWidgets(
    'confirms once, completes the reviewed orders, excludes later arrivals',
    (tester) async {
      final calls = <String>[];
      final orders = [queue(1), queue(2)];
      final first = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompleteAllOrdersButton(
              orders: orders,
              unpaidCount: 1,
              onComplete: (order) async {
                calls.add(order.id);
                return calls.length == 1 ? first.future : true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Complete All Orders'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(
        find.text('1 unpaid orders will stay in progress.'),
        findsOneWidget,
      );
      orders.add(queue(3));
      await tester.tap(find.text('Confirm Complete All'));
      await tester.pump();
      expect(calls, ['Q-1']);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm Complete All'),
            )
            .onPressed,
        isNull,
      );
      first.complete(true);
      await tester.pumpAndSettle();
      expect(calls, ['Q-1', 'Q-2']);
      expect(
        find.text('2 orders completed and saved in history.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cancel leaves orders alone; empty queue disables button', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompleteAllOrdersButton(
            orders: [queue(1)],
            onComplete: (_) async {
              calls++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Complete All Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep orders'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompleteAllOrdersButton(
            orders: [],
            onComplete: (_) async => true,
          ),
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('reports partial failure and continues the remaining orders', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompleteAllOrdersButton(
            orders: [queue(1), queue(2)],
            onComplete: (order) async {
              calls.add(order.id);
              if (order.id == 'Q-1') throw StateError('Save failed');
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Complete All Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Complete All'));
    await tester.pumpAndSettle();
    expect(calls, ['Q-1', 'Q-2']);
    expect(find.textContaining('1 of 2 orders completed.'), findsOneWidget);
  });
}
