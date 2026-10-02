import 'package:flutter/material.dart';
import '../../domain/coffee_pos_models.dart';

/// Requires a reason and explicit confirmation before changing terminal status.
class OrderStatusDialog extends StatefulWidget {
  const OrderStatusDialog({
    super.key,
    required this.action,
    required this.orderNumber,
    required this.amount,
    required this.onConfirm,
  });
  final OrderAction action;
  final int orderNumber;
  final double amount;
  final Future<bool> Function(String reason) onConfirm;
  @override
  State<OrderStatusDialog> createState() => _OrderStatusDialogState();
}

class _OrderStatusDialogState extends State<OrderStatusDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _returned = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refund = widget.action == OrderAction.refund;
    final complete = widget.action == OrderAction.complete;
    final title = refund
        ? 'Full Refund'
        : complete
        ? 'Complete order'
        : 'Cancel Order';
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text('$title #${widget.orderNumber}?'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${refund ? 'Refund amount' : 'Order total'}: ₱${widget.amount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 12),
                Text(
                  refund
                      ? 'Return the payment using the original payment method, then record the full refund here.'
                      : complete
                      ? 'Mark this order as completed and remove it from In Progress.'
                      : 'Cancel this order and keep the original transaction in history. Cancellation does not return a payment; use Refund if money needs to be returned.',
                ),
                if (!complete) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reason,
                    enabled: !_busy,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: refund
                          ? 'Refund reason'
                          : 'Cancellation reason',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a reason.'
                        : null,
                  ),
                ],
                if (refund)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I have returned the full amount to the customer.',
                    ),
                    value: _returned,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _returned = value ?? false),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: _busy || (refund && !_returned)
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    setState(() {
                      _busy = true;
                      _error = null;
                    });
                    try {
                      final saved = await widget.onConfirm(
                        complete ? 'Order completed' : _reason.text.trim(),
                      );
                      if (!context.mounted) return;
                      if (saved) {
                        Navigator.pop(context, true);
                      } else {
                        setState(() {
                          _busy = false;
                          _error =
                              'This order is already being updated. Please wait.';
                        });
                      }
                    } catch (error) {
                      if (mounted) {
                        setState(() {
                          _busy = false;
                          _error = error is StateError
                              ? error.message
                              : 'Could not save the status. Check your connection and try again.';
                        });
                      }
                    }
                  },
            child: Text(
              _busy
                  ? 'Saving…'
                  : refund
                  ? 'Confirm Full Refund'
                  : complete
                  ? 'Complete'
                  : 'Confirm Cancellation',
            ),
          ),
        ],
      ),
    );
  }
}
