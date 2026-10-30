import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/utils/printing/preparation_ticket_data.dart';

void main() {
  group('Delivery OrderQueueRecord', () {
    test('parses payload from Lunan customer app correctly', () {
      final payload = <String, dynamic>{
        'id': 'Q-20261030-001',
        'sequence': 1,
        'orderNumber': 'LUN-20261030-001',
        'status': 'pending',
        'customerName': 'Juan Dela Cruz',
        'orderType': 'Delivery (Delfin Albano)',
        'createdAt': '2026-10-30T15:00:00.000Z',
        'subtotal': 250.0,
        'deliveryFee': 40.0,
        'total': 290.0,
        'paymentMethod': 'gcash',
        'deliveryAddress': 'Poblacion 1, Delfin Albano, Isabela',
        'deliveryLandmark': 'Near Municipal Hall',
        'deliveryNotes': 'Call when arriving at green gate',
        'customerPhone': '09171234567',
        'customerEmail': 'juan@example.com',
        'items': [
          {
            'lineId': 'line-1',
            'productId': 'prod-spanish-latte',
            'productName': 'Spanish Latte',
            'unitPrice': 130.0,
            'quantity': 1,
            'modifierLabels': ['16oz (Large)', 'Oat Milk'],
            'lineTotal': 130.0,
            'selectedModifiers': [
              {
                'groupId': 'size',
                'optionId': '16oz',
                'label': '16oz (Large)',
                'priceDelta': 0.0,
              },
            ],
          },
          {
            'lineId': 'line-2',
            'productId': 'prod-croissant',
            'productName': 'Butter Croissant',
            'unitPrice': 120.0,
            'quantity': 1,
            'modifierLabels': <String>[],
            'lineTotal': 120.0,
            'selectedModifiers': <dynamic>[],
          },
        ],
      };

      final record = OrderQueueRecord.fromJson(payload);

      expect(record.id, 'Q-20261030-001');
      expect(record.displayOrderNumber, 'LUN-20261030-001');
      expect(record.status, OrderQueueStatus.pending);
      expect(record.customerName, 'Juan Dela Cruz');
      expect(record.customerPhone, '09171234567');
      expect(record.customerEmail, 'juan@example.com');
      expect(record.deliveryAddress, 'Poblacion 1, Delfin Albano, Isabela');
      expect(record.deliveryLandmark, 'Near Municipal Hall');
      expect(record.deliveryNotes, 'Call when arriving at green gate');
      expect(record.deliveryFee, 40.0);
      expect(record.paymentMethod, 'gcash');
      expect(record.isDelivery, isTrue);
      expect(record.subtotal, 250.0);
      expect(record.total, 290.0);
      expect(record.items, hasLength(2));

      // Roundtrip serialization
      final json = record.toJson();
      final roundtrip = OrderQueueRecord.fromJson(json);

      expect(roundtrip.id, record.id);
      expect(roundtrip.customerPhone, record.customerPhone);
      expect(roundtrip.deliveryAddress, record.deliveryAddress);
      expect(roundtrip.deliveryLandmark, record.deliveryLandmark);
      expect(roundtrip.deliveryNotes, record.deliveryNotes);
      expect(roundtrip.deliveryFee, record.deliveryFee);
      expect(roundtrip.paymentMethod, record.paymentMethod);
      expect(roundtrip.isDelivery, isTrue);
      expect(roundtrip.total, 290.0);
    });

    test('populates preparation ticket notes with delivery info if empty', () {
      final queue = OrderQueueRecord(
        id: 'Q-1',
        sequence: 1,
        status: OrderQueueStatus.pending,
        customerName: 'Maria',
        orderType: 'Delivery (Delfin Albano)',
        createdAt: DateTime(2026, 10, 30, 10, 0),
        items: const [],
        deliveryAddress: 'Brgy. San Antonio',
        deliveryNotes: 'Please ring bell',
      );

      final ticket = PreparationTicketData.fromQueueRecord(queue);
      expect(ticket.note, contains('Delivery to: Brgy. San Antonio'));
      expect(ticket.note, contains('Notes: Please ring bell'));
    });

    test('controller updateDeliveryStatus moves through preparing, onTheWay, delivered', () async {
      final repository = InMemoryCoffeePosRepository();
      final controller = CoffeePosController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      controller.updateCashierName('Jamie');
      controller.addProductToCart(controller.products.first);
      controller.updateCashReceived(1000);
      await controller.checkout();

      final queue = controller.activeOrders.single;
      expect(queue.status, OrderQueueStatus.preparing);

      // 1. Move to On the Way (OTW)
      await controller.updateDeliveryStatus(queue, OrderQueueStatus.onTheWay);
      expect(controller.activeOrders.single.status, OrderQueueStatus.onTheWay);

      // 2. Mark Delivered
      await controller.updateDeliveryStatus(controller.activeOrders.single, OrderQueueStatus.delivered);
      expect(controller.activeOrders, isEmpty);
      expect(controller.recentOrders, hasLength(1));
    });
  });
}

