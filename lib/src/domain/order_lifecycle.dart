import 'coffee_pos_models.dart';

/// Applies a terminal action atomically to the shared orders snapshot. All
/// financial line snapshots and the original transaction identity are retained.
class OrderLifecycle {
  static List<Map<String, dynamic>> records(Object? value) {
    final values = value is List
        ? value
        : value is Map
        ? value.values
        : const [];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// A delayed checkout sync must not resurrect a terminal order or overwrite
  /// an audit trail committed by another register.
  static Map<String, dynamic> merge(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final history = {
      for (final item in records(current['recentOrders'])) item['id']: item,
    };
    var sales = (current['todaySales'] as num?)?.toDouble() ?? 0;
    for (final item in records(incoming['recentOrders'])) {
      final old = history[item['id']];
      if (old == null) {
        history[item['id']] = item;
        final order = OrderRecord.fromJson(item);
        final now = DateTime.now();
        if (order.status == OrderStatus.paid &&
            order.createdAt.year == now.year &&
            order.createdAt.month == now.month &&
            order.createdAt.day == now.day) {
          sales += order.total;
        }
      } else if (records(old['statusHistory']).isEmpty &&
          old['status'] != 'voided' &&
          old['status'] != 'refunded') {
        history[item['id']] = item;
      }
    }
    final terminal = history.values
        .where(
          (item) =>
              records(item['statusHistory']).isNotEmpty ||
              item['status'] == 'voided' ||
              item['status'] == 'refunded',
        )
        .map((item) => item['id'])
        .toSet();
    final active = {
      for (final item in [
        ...records(current['activeOrders']),
        ...records(incoming['activeOrders']),
      ])
        if (!terminal.contains(transactionId(item['id'] as String)))
          item['id']: item,
    };
    return {
      ...current,
      ...incoming,
      'recentOrders': history.values.toList(),
      'activeOrders': active.values.toList(),
      'todaySales': sales,
    };
  }

  static String transactionId(String queueId) =>
      queueId.startsWith('Q-') ? queueId.substring(2) : queueId;

  static Map<String, dynamic> apply(
    Map<String, dynamic> state, {
    required String queueId,
    required OrderAction action,
    required String reason,
    required String userId,
    required String cashierName,
    required DateTime at,
    double? expectedRefundAmount,
  }) {
    if (action != OrderAction.complete &&
        (reason.trim().isEmpty || reason.trim().length > 500)) {
      throw StateError('A reason is required.');
    }
    final active = records(state['activeOrders']);
    final queueIndex = active.indexWhere((item) => item['id'] == queueId);
    if (queueIndex < 0) {
      throw StateError(
        'This order is no longer in progress. Refresh its status.',
      );
    }
    final queue = OrderQueueRecord.fromJson(active[queueIndex]);
    final history = records(state['recentOrders']);
    final id = transactionId(queueId);
    final index = history.indexWhere((item) => item['id'] == id);
    final original = index < 0 ? null : OrderRecord.fromJson(history[index]);
    if (original != null &&
        original.status != OrderStatus.paid &&
        original.status != OrderStatus.draft) {
      throw StateError('This transaction is already cancelled or refunded.');
    }
    if (action == OrderAction.refund &&
        (original == null ||
            original.status != OrderStatus.paid ||
            !original.total.isFinite ||
            original.total <= 0)) {
      throw StateError('Only a paid transaction can be refunded.');
    }
    if (action == OrderAction.refund &&
        expectedRefundAmount != original!.total) {
      throw StateError('The refund amount changed. Review the order again.');
    }
    if (action == OrderAction.complete &&
        (original == null || original.status != OrderStatus.paid)) {
      throw StateError('Collect payment before completing this order.');
    }
    final record =
        original ??
        OrderRecord(
          id: id,
          sequence: queue.sequence,
          status: OrderStatus.draft,
          orderType: queue.orderType,
          paymentType: PaymentType.cash,
          cashierName: cashierName,
          createdAt: queue.createdAt,
          subtotal: queue.subtotal,
          discount: 0,
          tax: 0,
          serviceCharge: 0,
          total: queue.subtotal,
          cashReceived: 0,
          change: 0,
          items: queue.items,
          vatEnabled: false,
        );
    final audit = OrderStatusChange(
      action: action,
      reason: reason.trim(),
      userId: userId,
      cashierName: cashierName,
      at: at,
      amount: action == OrderAction.refund ? record.total : 0,
    );
    final updated = {
      ...record.toJson(),
      'status': switch (action) {
        OrderAction.complete => OrderStatus.paid.name,
        OrderAction.cancel => OrderStatus.voided.name,
        OrderAction.refund => OrderStatus.refunded.name,
      },
      'originalQueue': record.originalQueue?.toJson() ?? queue.toJson(),
      'statusHistory': [
        ...record.statusHistory.map((entry) => entry.toJson()),
        audit.toJson(),
      ],
    };
    if (index < 0) {
      history.insert(0, updated);
    } else {
      history[index] = updated;
    }
    active.removeAt(queueIndex);
    var sales = (state['todaySales'] as num?)?.toDouble() ?? 0;
    if (action != OrderAction.complete &&
        original?.status == OrderStatus.paid &&
        original!.createdAt.year == at.year &&
        original.createdAt.month == at.month &&
        original.createdAt.day == at.day) {
      sales = (sales - original.total).clamp(0, double.infinity);
    }
    return {
      ...state,
      'activeOrders': active,
      'recentOrders': history,
      'todaySales': sales,
    };
  }
}
