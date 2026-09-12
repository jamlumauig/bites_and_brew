import '../domain/checkout_calculator.dart';
import '../domain/coffee_pos_models.dart';

abstract class CoffeePosRepository {
  Future<StoreBootstrap> loadBootstrap();
  Future<OrderRecord> createOrder(OrderDraft draft);
}

class InMemoryCoffeePosRepository implements CoffeePosRepository {
  InMemoryCoffeePosRepository() : _bootstrap = StoreBootstrap.sample();

  final StoreBootstrap _bootstrap;
  final List<OrderRecord> _orders = <OrderRecord>[];

  @override
  Future<StoreBootstrap> loadBootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _bootstrap;
  }

  @override
  Future<OrderRecord> createOrder(OrderDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final totals = const CheckoutCalculator().calculate(
      cartItems: draft.lines
          .map(
            (line) => CartItem(
              product: Product(
                id: line.productId,
                name: line.productName,
                categoryId: '',
                price: line.unitPrice,
                description: '',
                badge: '',
                modifierGroupIds: const <String>[],
              ),
              quantity: line.quantity,
              selectedModifiers: line.modifierLabels
                  .map(
                    (label) => SelectedModifier(
                      groupId: '',
                      optionId: '',
                      label: label,
                      priceDelta: 0,
                    ),
                  )
                  .toList(growable: false),
              lineId: line.lineId,
            ),
          )
          .toList(growable: false),
      discountAmount: draft.discountAmount,
      taxRate: draft.taxRate,
      serviceChargeRate: draft.serviceChargeRate,
      cashReceived: draft.cashReceived,
      discountApplication: draft.discountApplication,
    );
    final order = OrderRecord.fromCalculatedTotals(
      draft: draft,
      totals: totals,
      sequence: _orders.length + 1,
    );
    _orders.add(order);
    return order;
  }
}
