import 'package:flutter/foundation.dart';

import '../../domain/coffee_pos_models.dart';

/// Item representation on a barista/kitchen preparation ticket.
///
/// Contains preparation details only (item name, quantity, modifiers/add-ons).
/// Zero financial or pricing information.
@immutable
class PreparationTicketItem {
  const PreparationTicketItem({
    required this.name,
    required this.quantity,
    this.modifierLabels = const <String>[],
  });

  final String name;
  final int quantity;
  final List<String> modifierLabels;

  factory PreparationTicketItem.fromSnapshot(OrderLineSnapshot snapshot) {
    return PreparationTicketItem(
      name: snapshot.productName,
      quantity: snapshot.quantity,
      modifierLabels: List<String>.unmodifiable(snapshot.modifierLabels),
    );
  }
}

/// Normalized model for Barista / Kitchen preparation tickets.
///
/// Strictly contains preparation information (Order #, Type, Items, Modifiers, Notes).
/// Completely excludes financial information (prices, subtotal, discounts, tax, totals, payment).
@immutable
class PreparationTicketData {
  const PreparationTicketData({
    required this.orderId,
    required this.sequence,
    this.orderNumber,
    required this.orderType,
    required this.createdAt,
    required this.items,
    this.customerName = '',
    this.note = '',
    this.printerName = '',
  });

  final String orderId;
  final int sequence;
  final String? orderNumber;
  final String orderType;
  final DateTime createdAt;
  final List<PreparationTicketItem> items;
  final String customerName;
  final String note;
  final String printerName;

  String get displayOrderNumber {
    if (orderNumber != null && orderNumber!.isNotEmpty) {
      return orderNumber!;
    }
    return sequence > 0 ? '$sequence' : orderId;
  }

  factory PreparationTicketData.fromOrderRecord(
    OrderRecord order, {
    String note = '',
    String printerName = '',
  }) {
    return PreparationTicketData(
      orderId: order.id,
      sequence: order.sequence,
      orderNumber: order.orderNumber,
      orderType: order.orderType,
      createdAt: order.createdAt,
      items: order.items
          .map(PreparationTicketItem.fromSnapshot)
          .toList(growable: false),
      customerName: '',
      note: note,
      printerName: printerName,
    );
  }

  factory PreparationTicketData.fromQueueRecord(
    OrderQueueRecord queue, {
    String note = '',
    String printerName = '',
  }) {
    final effectiveNote = note.isNotEmpty
        ? note
        : [
            if (queue.deliveryAddress != null && queue.deliveryAddress!.isNotEmpty)
              'Delivery to: ${queue.deliveryAddress}',
            if (queue.deliveryNotes != null && queue.deliveryNotes!.isNotEmpty)
              'Notes: ${queue.deliveryNotes}',
          ].join(' | ');

    return PreparationTicketData(
      orderId: queue.id,
      sequence: queue.sequence,
      orderNumber: queue.displayOrderNumber,
      orderType: queue.orderType,
      createdAt: queue.createdAt,
      items: queue.items
          .map(PreparationTicketItem.fromSnapshot)
          .toList(growable: false),
      customerName: queue.customerName,
      note: effectiveNote,
      printerName: printerName,
    );
  }
}

