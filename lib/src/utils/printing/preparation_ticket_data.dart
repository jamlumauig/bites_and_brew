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
    required this.orderType,
    required this.createdAt,
    required this.items,
    this.customerName = '',
    this.note = '',
    this.printerName = '',
  });

  final String orderId;
  final int sequence;
  final String orderType;
  final DateTime createdAt;
  final List<PreparationTicketItem> items;
  final String customerName;
  final String note;
  final String printerName;

  factory PreparationTicketData.fromOrderRecord(
    OrderRecord order, {
    String note = '',
    String printerName = '',
  }) {
    return PreparationTicketData(
      orderId: order.id,
      sequence: order.sequence,
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
    return PreparationTicketData(
      orderId: queue.id,
      sequence: queue.sequence,
      orderType: queue.orderType,
      createdAt: queue.createdAt,
      items: queue.items
          .map(PreparationTicketItem.fromSnapshot)
          .toList(growable: false),
      customerName: queue.customerName,
      note: note,
      printerName: printerName,
    );
  }
}

