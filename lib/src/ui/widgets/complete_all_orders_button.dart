import 'package:flutter/material.dart';
import '../../domain/coffee_pos_models.dart';

/// Runs the existing audited completion action for the orders the cashier
/// reviewed. Orders arriving after confirmation are not included.
class CompleteAllOrdersButton extends StatefulWidget {
  const CompleteAllOrdersButton({
    super.key,
    required this.orders,
    required this.onComplete,
    this.unpaidCount = 0,
  });
  final List<OrderQueueRecord> orders;
  final Future<bool> Function(OrderQueueRecord) onComplete;
  final int unpaidCount;
  @override
  State<CompleteAllOrdersButton> createState() =>
      _CompleteAllOrdersButtonState();
}

class _CompleteAllOrdersButtonState extends State<CompleteAllOrdersButton> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    icon: const Icon(Icons.done_all),
    label: const Text('Complete All Orders'),
    onPressed: _open || widget.orders.isEmpty
        ? null
        : () async {
            setState(() => _open = true);
            final orders = List<OrderQueueRecord>.unmodifiable(widget.orders);
            final onComplete = widget.onComplete;
            var busy = false;
            var completed = 0;
            var processed = 0;
            String? result;
            try {
              await showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => StatefulBuilder(
                  builder: (context, update) => PopScope(
                    canPop: !busy,
                    child: AlertDialog(
                      title: const Text('Complete all orders?'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark ${orders.length} paid orders as completed? Their transactions and completion details will remain in history.',
                          ),
                          if (widget.unpaidCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${widget.unpaidCount} unpaid orders will stay in progress.',
                            ),
                          ],
                          if (busy) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: processed / orders.length,
                            ),
                            Text(
                              'Completing orders: $processed / ${orders.length}',
                            ),
                          ],
                          if (result != null) ...[
                            const SizedBox(height: 12),
                            Text(result!),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: Text(result == null ? 'Keep orders' : 'Done'),
                        ),
                        if (result == null)
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    update(() => busy = true);
                                    for (final order in orders) {
                                      try {
                                        if (await onComplete(order)) {
                                          completed++;
                                        }
                                      } catch (_) {
                                        // Preserve any successful completions; failed or stale orders
                                        // retain their current status and can be reviewed individually.
                                      }
                                      processed++;
                                      if (context.mounted) update(() {});
                                    }
                                    if (context.mounted) {
                                      update(() {
                                        busy = false;
                                        result = completed == orders.length
                                            ? '$completed orders completed and saved in history.'
                                            : '$completed of ${orders.length} orders completed. ${orders.length - completed} could not be completed. Review their status and connection before trying again.';
                                      });
                                    }
                                  },
                            child: const Text('Confirm Complete All'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            } finally {
              if (mounted) setState(() => _open = false);
            }
          },
  );
}
