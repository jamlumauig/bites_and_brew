import 'package:flutter/material.dart';

import '../../domain/coffee_pos_models.dart';
import '../../state/coffee_pos_controller.dart';

class DiscountSettingsDialog extends StatefulWidget {
  const DiscountSettingsDialog({super.key, required this.controller});

  final CoffeePosController controller;

  @override
  State<DiscountSettingsDialog> createState() => _DiscountSettingsDialogState();
}

class _DiscountSettingsDialogState extends State<DiscountSettingsDialog> {
  late bool _enabled = widget.controller.discountsEnabled;
  late final List<DiscountOption> _options = List.of(
    widget.controller.discountOptions,
  );
  String? _error;

  Future<void> _edit([DiscountOption? option]) async {
    final result = await showDialog<DiscountOption>(
      context: context,
      builder: (_) => _DiscountEditor(option: option),
    );
    if (result == null || !mounted) return;
    setState(() {
      _error = null;
      if (option == null) {
        _options.add(result);
      } else {
        _options[_options.indexOf(option)] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Discount Options'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable discounts'),
              subtitle: const Text(
                'Allow cashiers to select a discount at checkout.',
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const Divider(),
            for (final option in _options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Switch(
                      value: option.enabled,
                      onChanged: (value) => setState(() {
                        _options[_options.indexOf(option)] = option.copyWith(
                          enabled: value,
                        );
                      }),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(option.name),
                        subtitle: Text(
                          option.isStatutory
                              ? '20% · Uses existing Senior / PWD calculation'
                              : option.type == DiscountType.percentage
                              ? '${option.value.toStringAsFixed(2)}%'
                              : '${widget.controller.currencySymbol}${option.value.toStringAsFixed(2)}',
                        ),
                        onTap: () => _edit(option),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit ${option.name}',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(option),
                    ),
                    if (!option.isStatutory)
                      IconButton(
                        tooltip: 'Remove ${option.name}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            setState(() => _options.remove(option)),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add discount'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          try {
            widget.controller.updateDiscountSettings(
              enabled: _enabled,
              options: _options,
            );
            Navigator.pop(context);
          } on ArgumentError catch (error) {
            setState(() => _error = error.message.toString());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _DiscountEditor extends StatefulWidget {
  const _DiscountEditor({this.option});
  final DiscountOption? option;

  @override
  State<_DiscountEditor> createState() => _DiscountEditorState();
}

class _DiscountEditorState extends State<_DiscountEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.option?.name ?? '');
  late final _value = TextEditingController(
    text: widget.option?.value.toString() ?? '',
  );
  late DiscountType _type = widget.option?.type ?? DiscountType.percentage;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.option == null ? 'Add discount' : 'Edit discount'),
    content: SizedBox(
      width: 360,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Discount name'),
                maxLength: 60,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              if (!(widget.option?.isStatutory ?? false)) ...[
                DropdownButtonFormField<DiscountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Discount type'),
                  items: const [
                    DropdownMenuItem(
                      value: DiscountType.percentage,
                      child: Text('Percentage (%)'),
                    ),
                    DropdownMenuItem(
                      value: DiscountType.fixedAmount,
                      child: Text('Fixed amount'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _type = value!),
                ),
                TextFormField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _type == DiscountType.percentage
                        ? 'Percentage'
                        : 'Amount',
                  ),
                  validator: (text) {
                    final value = double.tryParse(text ?? '');
                    if (value == null || !value.isFinite || value <= 0) {
                      return 'Enter an amount greater than zero';
                    }
                    if (_type == DiscountType.percentage && value > 100) {
                      return 'Percentage cannot exceed 100';
                    }
                    return null;
                  },
                ),
              ] else
                const Text(
                  'Uses the existing Senior Citizen / PWD calculation.',
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            DiscountOption(
              id:
                  widget.option?.id ??
                  'custom-${DateTime.now().microsecondsSinceEpoch}',
              name: _name.text.trim(),
              type: _type,
              value: widget.option?.isStatutory == true
                  ? 20
                  : double.parse(_value.text),
              enabled: widget.option?.enabled ?? true,
            ),
          );
        },
        child: const Text('Done'),
      ),
    ],
  );
}

class CheckoutDiscountSelector extends StatelessWidget {
  const CheckoutDiscountSelector({super.key, required this.controller});
  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.discountsEnabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        key: ValueKey(controller.selectedDiscountId),
        initialValue: controller.selectedDiscountId ?? '',
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Discount',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('No discount')),
          for (final option in controller.availableDiscounts)
            DropdownMenuItem(
              value: option.id,
              child: Text(option.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: controller.isCheckingOut
            ? null
            : (value) => controller.selectDiscount(value == '' ? null : value),
      ),
    );
  }
}
