import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/domain/order_lifecycle.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final action in OrderAction.values) {
    test(
      '$action preserves transaction and audit across reload; rejects duplicate actions',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = InMemoryCoffeePosRepository();
        final controller = CoffeePosController(repository: repository);
        addTearDown(controller.dispose);
        await controller.initialize();
        controller.updateCashierName('Jamie');
        controller.addProductToCart(controller.products.first);
        controller.updateCashReceived(1000);
        final order = (await controller.checkout())!;
        final queue = controller.activeOrders.single;
        final original = order.toJson();
        if (action != OrderAction.complete) {
          await expectLater(
            controller.changeOrderStatus(queue, action: action, reason: ' '),
            throwsStateError,
          );
          expect(controller.activeOrders, hasLength(1));
        }
        if (action == OrderAction.refund) {
          await expectLater(
            controller.changeOrderStatus(
              queue,
              action: action,
              reason: 'Wrong amount',
              expectedRefundAmount: order.total + 1,
            ),
            throwsStateError,
          );
          expect(controller.activeOrders, hasLength(1));
        }
        final changed = await controller.changeOrderStatus(
          queue,
          action: action,
          reason: 'Customer request',
          expectedRefundAmount: order.total,
        );
        expect(changed, isTrue);
        expect(controller.activeOrders, isEmpty);
        expect(controller.recentOrders, hasLength(1));
        final saved = controller.recentOrders.single;
        expect(saved.status, switch (action) {
          OrderAction.complete => OrderStatus.paid,
          OrderAction.cancel => OrderStatus.voided,
          OrderAction.refund => OrderStatus.refunded,
        });
        expect(
          saved.items.map((item) => item.toJson()).toList(),
          original['items'],
        );
        expect(saved.total, order.total);
        expect(saved.id, order.id);
        expect(saved.createdAt, order.createdAt);
        expect(saved.originalQueue!.id, queue.id);
        expect(saved.statusHistory.single.reason, 'Customer request');
        expect(saved.statusHistory.single.cashierName, 'Jamie');
        expect(saved.statusHistory.single.userId, 'local');
        expect(
          saved.statusHistory.single.amount,
          action == OrderAction.refund ? order.total : 0,
        );
        await expectLater(
          controller.changeOrderStatus(
            queue,
            action: action,
            reason: 'Again',
            expectedRefundAmount: order.total,
          ),
          throwsStateError,
        );
        final reloaded = CoffeePosController(repository: repository);
        addTearDown(reloaded.dispose);
        await reloaded.initialize();
        expect(reloaded.activeOrders, isEmpty);
        expect(reloaded.recentOrders.single.toJson(), saved.toJson());

        final stale = {
          'recentOrders': [original],
          'activeOrders': [queue.toJson()],
          'todaySales': order.total,
        };
        final latest = {
          'recentOrders': [saved.toJson()],
          'activeOrders': [],
          'todaySales': controller.todaySales,
        };
        final merged = OrderLifecycle.merge(latest, stale);
        expect(OrderLifecycle.records(merged['activeOrders']), isEmpty);
        expect(
          OrderLifecycle.records(merged['recentOrders']).single,
          saved.toJson(),
        );
      },
    );
  }

  test('unpaid cancel archives all queue details; unpaid refund rejected', () {
    final queue = OrderQueueRecord(
      id: 'Q-unpaid',
      sequence: 1,
      status: OrderQueueStatus.held,
      customerName: 'Taylor',
      orderType: 'Take-out',
      createdAt: DateTime.now(),
      items: const [
        OrderLineSnapshot(
          lineId: '1',
          productId: 'coffee',
          productName: 'Coffee',
          unitPrice: 100,
          quantity: 1,
          modifierLabels: [],
          lineTotal: 100,
        ),
      ],
    );
    final state = {
      'activeOrders': [queue.toJson()],
      'recentOrders': [],
      'todaySales': 0,
    };
    expect(
      () => OrderLifecycle.apply(
        state,
        queueId: queue.id,
        action: OrderAction.refund,
        reason: 'Reason',
        userId: 'u1',
        cashierName: 'Pat',
        at: DateTime.now(),
        expectedRefundAmount: 100,
      ),
      throwsStateError,
    );
    final result = OrderLifecycle.apply(
      state,
      queueId: queue.id,
      action: OrderAction.cancel,
      reason: 'Out of stock',
      userId: 'u1',
      cashierName: 'Pat',
      at: DateTime.now(),
    );
    final record = OrderRecord.fromJson(
      OrderLifecycle.records(result['recentOrders']).single,
    );
    expect(record.status, OrderStatus.voided);
    expect(record.originalQueue!.toJson(), queue.toJson());
    expect(record.statusHistory.single.userId, 'u1');
    expect(result['todaySales'], 0);
  });
}
