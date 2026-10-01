import 'package:flutter/foundation.dart';

import '../../domain/coffee_pos_models.dart';
import 'preparation_ticket_data.dart';

/// Represents a modifier or add-on on a printed receipt.
@immutable
class ReceiptModifier {
  const ReceiptModifier({
    required this.name,
    this.priceDelta = 0.0,
    this.isDefault = false,
  });

  final String name;
  final double priceDelta;
  final bool isDefault;
}

/// Represents an individual item on a printed receipt.
@immutable
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.modifierLabels = const <String>[],
    this.modifiers = const <ReceiptModifier>[],
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<String> modifierLabels;
  final List<ReceiptModifier> modifiers;

  factory ReceiptItem.fromSnapshot(OrderLineSnapshot snapshot) {
    List<ReceiptModifier> mods;
    if (snapshot.selectedModifiers.isNotEmpty) {
      mods = snapshot.selectedModifiers
          .map(
            (m) => ReceiptModifier(
              name: m.name,
              priceDelta: m.priceDelta,
              isDefault: m.isDefault,
            ),
          )
          .toList(growable: false);
    } else {
      mods = snapshot.modifierLabels
          .map((label) => ReceiptModifier(name: label))
          .toList(growable: false);
    }

    return ReceiptItem(
      name: snapshot.productName,
      quantity: snapshot.quantity,
      unitPrice: snapshot.unitPrice,
      lineTotal: snapshot.lineTotal,
      modifierLabels: List<String>.unmodifiable(snapshot.modifierLabels),
      modifiers: List<ReceiptModifier>.unmodifiable(mods),
    );
  }
}

/// Normalized, validated printable receipt model.
@immutable
class ReceiptData {
  const ReceiptData({
    required this.orderId,
    required this.sequence,
    required this.orderType,
    required this.paymentType,
    required this.cashierName,
    required this.createdAt,
    required this.storeName,
    required this.storeAddress,
    required this.storeContact,
    required this.receiptHeader,
    required this.receiptFooter,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.serviceCharge,
    required this.total,
    required this.cashReceived,
    required this.change,
    this.vatableSales = 0.0,
    this.vatExemptSales = 0.0,
    this.vatExemptionAmount = 0.0,
    this.seniorDiscount = 0.0,
    this.pwdDiscount = 0.0,
    this.otherDiscount = 0.0,
    this.printerName = '',
    this.vatEnabled = true,
    this.preparationTicket,
  });

  /// When present, all builders produce one customer + kitchen document.
  final PreparationTicketData? preparationTicket;

  final String orderId;
  final int sequence;
  final String orderType;
  final String paymentType;
  final String cashierName;
  final DateTime createdAt;
  final String storeName;
  final String storeAddress;
  final String storeContact;
  final String receiptHeader;
  final String receiptFooter;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double serviceCharge;
  final double total;
  final double cashReceived;
  final double change;
  final double vatableSales;
  final double vatExemptSales;
  final double vatExemptionAmount;
  final double seniorDiscount;
  final double pwdDiscount;
  final double otherDiscount;
  final String printerName;
  final bool vatEnabled;

  factory ReceiptData.fromOrderRecord({
    required OrderRecord order,
    required String storeName,
    required String storeAddress,
    required String storeContact,
    required String receiptHeader,
    required String receiptFooter,
    String printerName = '',
    bool includeKitchen = false,
  }) {
    return ReceiptData(
      preparationTicket: includeKitchen
          ? PreparationTicketData.fromOrderRecord(order)
          : null,
      orderId: order.id,
      sequence: order.sequence,
      orderType: order.orderType,
      paymentType: order.paymentType.name.toUpperCase(),
      cashierName: order.cashierName,
      createdAt: order.createdAt,
      storeName: storeName,
      storeAddress: storeAddress,
      storeContact: storeContact,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
      items: order.items.map(ReceiptItem.fromSnapshot).toList(growable: false),
      subtotal: order.subtotal,
      discount: order.discount,
      tax: order.tax,
      serviceCharge: order.serviceCharge,
      total: order.total,
      cashReceived: order.cashReceived,
      change: order.change,
      vatableSales: order.vatableSales,
      vatExemptSales: order.vatExemptSales,
      vatExemptionAmount: order.vatExemptionAmount,
      seniorDiscount: order.seniorDiscount,
      pwdDiscount: order.pwdDiscount,
      otherDiscount: order.otherDiscount,
      printerName: printerName,
      vatEnabled: order.vatEnabled,
    );
  }
}
