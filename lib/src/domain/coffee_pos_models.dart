enum Role { cashier, admin }

enum OrderStatus { draft, paid, voided, refunded }

enum OrderQueueStatus { pending, preparing, held, awaitingPayment }

enum DiscountType { none, seniorCitizen, pwd, percentage, fixedAmount }

enum PaymentType { cash, card, eWallet }

enum InventorySeverity { good, warning, critical }

class StoreBootstrap {
  const StoreBootstrap({
    required this.categories,
    required this.products,
    required this.modifierGroups,
    required this.inventoryHealth,
    required this.todaySales,
    required this.recentOrders,
    required this.activeShifts,
    required this.activeOrders,
    required this.customers,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<ModifierGroup> modifierGroups;
  final List<InventoryHealth> inventoryHealth;
  final List<ShiftSummary> activeShifts;
  final List<OrderQueueRecord> activeOrders;
  final List<CustomerProfile> customers;
  final List<OrderRecord> recentOrders;
  final double todaySales;

  factory StoreBootstrap.empty() {
    return const StoreBootstrap(
      categories: <Category>[],
      products: <Product>[],
      modifierGroups: <ModifierGroup>[],
      inventoryHealth: <InventoryHealth>[],
      todaySales: 0,
      recentOrders: <OrderRecord>[],
      activeShifts: <ShiftSummary>[],
      activeOrders: <OrderQueueRecord>[],
      customers: <CustomerProfile>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'categories': categories
          .map((item) => item.toJson())
          .toList(growable: false),
      'products': products.map((item) => item.toJson()).toList(growable: false),
      'modifierGroups': modifierGroups
          .map((item) => item.toJson())
          .toList(growable: false),
      'inventoryHealth': inventoryHealth
          .map((item) => item.toJson())
          .toList(growable: false),
      'activeShifts': activeShifts
          .map((item) => item.toJson())
          .toList(growable: false),
      'activeOrders': activeOrders
          .map((item) => item.toJson())
          .toList(growable: false),
      'customers': customers
          .map((item) => item.toJson())
          .toList(growable: false),
      'recentOrders': recentOrders
          .map((item) => item.toJson())
          .toList(growable: false),
      'todaySales': todaySales,
    };
  }

  factory StoreBootstrap.fromJson(Map<String, dynamic> json) {
    return StoreBootstrap(
      categories: _readList(json['categories'], Category.fromJson),
      products: _readList(json['products'], Product.fromJson),
      modifierGroups: _readList(json['modifierGroups'], ModifierGroup.fromJson),
      inventoryHealth: _readList(
        json['inventoryHealth'],
        InventoryHealth.fromJson,
      ),
      todaySales: _numValue(json['todaySales']),
      recentOrders: _readList(json['recentOrders'], OrderRecord.fromJson),
      activeShifts: _readList(json['activeShifts'], ShiftSummary.fromJson),
      activeOrders: _readList(json['activeOrders'], OrderQueueRecord.fromJson),
      customers: _readList(json['customers'], CustomerProfile.fromJson),
    );
  }

  static StoreBootstrap sample() {
    const categories = <Category>[
      Category(id: 'coffee', name: 'Coffee', icon: '☕'),
      Category(id: 'shakes', name: 'Shakes', icon: '🥤'),
      Category(id: 'snacks', name: 'Snacks', icon: '🥐'),
      Category(id: 'ala-carte', name: 'Ala Carte', icon: '🍽️'),
      Category(id: 'combos', name: 'Combos', icon: '🍱'),
      Category(id: 'desserts', name: 'Desserts', icon: '🍰'),
    ];

    const modifierGroups = <ModifierGroup>[
      ModifierGroup(
        id: 'drink-size',
        name: 'Drink size',
        options: <ModifierOption>[
          ModifierOption(
            id: '16oz',
            name: '16 oz',
            priceDelta: 0,
            isDefault: true,
          ),
          ModifierOption(id: '22oz', name: '22 oz', priceDelta: 32),
        ],
        minSelected: 1,
        maxSelected: 1,
      ),
      ModifierGroup(
        id: 'snack-size',
        name: 'Snack size',
        options: <ModifierOption>[
          ModifierOption(
            id: 'small',
            name: 'Small',
            priceDelta: 0,
            isDefault: true,
          ),
          ModifierOption(id: 'large', name: 'Large', priceDelta: 20),
        ],
        minSelected: 1,
        maxSelected: 1,
      ),
      ModifierGroup(
        id: 'milk',
        name: 'Milk',
        options: <ModifierOption>[
          ModifierOption(
            id: 'regular',
            name: 'Regular Milk',
            priceDelta: 0,
            isDefault: true,
          ),
          ModifierOption(id: 'oat', name: 'Oat Milk', priceDelta: 26),
          ModifierOption(id: 'almond', name: 'Almond Milk', priceDelta: 22),
        ],
        minSelected: 1,
        maxSelected: 1,
      ),
      ModifierGroup(
        id: 'extras',
        name: 'Extras',
        options: <ModifierOption>[
          ModifierOption(id: 'shot', name: 'Extra Shot', priceDelta: 20),
          ModifierOption(id: 'syrup', name: 'Vanilla Syrup', priceDelta: 15),
          ModifierOption(id: 'whip', name: 'Whipped Cream', priceDelta: 12),
        ],
        minSelected: 0,
        maxSelected: 3,
      ),
    ];

    final products = <Product>[
      Product(
        id: 'latte',
        name: 'Signature Latte',
        categoryId: 'coffee',
        price: 145,
        description: 'Smooth espresso, steamed milk, caramel finish.',
        badge: 'Top seller',
        modifierGroupIds: const ['drink-size', 'milk', 'extras'],
      ),
      Product(
        id: 'americano',
        name: 'House Americano',
        categoryId: 'coffee',
        price: 110,
        description: 'Bright espresso with hot water and clean finish.',
        badge: 'Fast prep',
        modifierGroupIds: const ['drink-size', 'extras'],
      ),
      Product(
        id: 'mocha',
        name: 'Iced Mocha',
        categoryId: 'coffee',
        price: 158,
        description: 'Chocolate, espresso, and cold milk over ice.',
        badge: 'Popular',
        modifierGroupIds: const ['drink-size', 'milk', 'extras'],
      ),
      Product(
        id: 'matcha',
        name: 'Matcha Cloud',
        categoryId: 'shakes',
        price: 162,
        description: 'Ceremonial matcha with creamy milk foam.',
        badge: 'New',
        modifierGroupIds: const ['drink-size', 'milk'],
      ),
      Product(
        id: 'yuzu',
        name: 'Yuzu Sparkler',
        categoryId: 'shakes',
        price: 125,
        description: 'Citrus soda with a refreshing finish.',
        badge: 'Chilled',
        modifierGroupIds: const ['drink-size'],
      ),
      Product(
        id: 'croissant',
        name: 'Butter Croissant',
        categoryId: 'snacks',
        price: 78,
        description: 'Flaky, golden, baked fresh throughout the day.',
        badge: 'Fresh bake',
        modifierGroupIds: const ['snack-size'],
      ),
      Product(
        id: 'sandwich',
        name: 'Chicken Pesto Toast',
        categoryId: 'snacks',
        price: 138,
        description: 'Toasted sandwich with basil pesto and cheese.',
        badge: 'Ready to serve',
        modifierGroupIds: const ['snack-size'],
      ),
      Product(
        id: 'cheesecake',
        name: 'Burnt Cheesecake',
        categoryId: 'desserts',
        price: 168,
        description: 'Creamy center with a caramelized top.',
        badge: 'Dessert pick',
        modifierGroupIds: const [],
      ),
    ];

    return StoreBootstrap(
      categories: categories,
      products: products,
      modifierGroups: modifierGroups,
      inventoryHealth: const <InventoryHealth>[],
      activeShifts: const <ShiftSummary>[],
      activeOrders: const <OrderQueueRecord>[],
      customers: const <CustomerProfile>[],
      recentOrders: const <OrderRecord>[],
      todaySales: 0,
    );
  }
}

class Category {
  const Category({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final String icon;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'icon': icon,
  };

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.description,
    required this.badge,
    required this.modifierGroupIds,
  });

  final String id;
  final String name;
  final String categoryId;
  final double price;
  final String description;
  final String badge;
  final List<String> modifierGroupIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'price': price,
    'description': description,
    'badge': badge,
    'modifierGroupIds': modifierGroupIds,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      price: _numValue(json['price']),
      description: json['description'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
      modifierGroupIds: _readStringList(json['modifierGroupIds']),
    );
  }
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.options,
    required this.minSelected,
    required this.maxSelected,
  });

  final String id;
  final String name;
  final List<ModifierOption> options;
  final int minSelected;
  final int maxSelected;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'options': options.map((item) => item.toJson()).toList(growable: false),
    'minSelected': minSelected,
    'maxSelected': maxSelected,
  };

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    return ModifierGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      options: _readList(json['options'], ModifierOption.fromJson),
      minSelected: _intValue(json['minSelected']),
      maxSelected: _intValue(json['maxSelected']),
    );
  }
}

class ModifierOption {
  const ModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final double priceDelta;
  final bool isDefault;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'priceDelta': priceDelta,
    'isDefault': isDefault,
  };

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceDelta: _numValue(json['priceDelta']),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class SelectedModifier {
  const SelectedModifier({
    required this.groupId,
    required this.optionId,
    required this.label,
    required this.priceDelta,
    this.isDefault = false,
  });

  final String groupId;
  final String optionId;
  final String label;
  final double priceDelta;
  final bool isDefault;

  String get name => label;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'groupId': groupId,
    'optionId': optionId,
    'label': label,
    'priceDelta': priceDelta,
    'isDefault': isDefault,
  };

  factory SelectedModifier.fromJson(Map<String, dynamic> json) {
    return SelectedModifier(
      groupId: json['groupId'] as String? ?? '',
      optionId: json['optionId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      priceDelta: _numValue(json['priceDelta']),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class DiscountApplication {
  const DiscountApplication({
    required this.type,
    this.percentage = 0,
    this.fixedAmount = 0,
    this.holderName,
    this.idNumber,
    this.eligiblePersons = 1,
    this.eligibleLineIds = const <String>[],
  });

  const DiscountApplication.none()
    : type = DiscountType.none,
      percentage = 0,
      fixedAmount = 0,
      holderName = null,
      idNumber = null,
      eligiblePersons = 1,
      eligibleLineIds = const <String>[];

  final DiscountType type;
  final double percentage;
  final double fixedAmount;
  final String? holderName;
  final String? idNumber;
  final int eligiblePersons;
  final List<String> eligibleLineIds;

  bool get isStatutory =>
      type == DiscountType.seniorCitizen || type == DiscountType.pwd;

  bool get isPromotional =>
      type == DiscountType.percentage || type == DiscountType.fixedAmount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'percentage': percentage,
    'fixedAmount': fixedAmount,
    'holderName': holderName,
    'idNumber': idNumber,
    'eligiblePersons': eligiblePersons,
    'eligibleLineIds': eligibleLineIds,
  };

  factory DiscountApplication.fromJson(Map<String, dynamic> json) {
    return DiscountApplication(
      type: _enumFromName(
        DiscountType.values,
        json['type'] as String?,
        DiscountType.none,
      ),
      percentage: _numValue(json['percentage']),
      fixedAmount: _numValue(json['fixedAmount']),
      holderName: json['holderName'] as String?,
      idNumber: json['idNumber'] as String?,
      eligiblePersons: _intValue(json['eligiblePersons'], 1),
      eligibleLineIds: _readStringList(json['eligibleLineIds']),
    );
  }
}

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    required this.selectedModifiers,
    this.lineId,
  });

  final Product product;
  final int quantity;
  final List<SelectedModifier> selectedModifiers;
  final String? lineId;

  double get singleItemPrice =>
      product.price +
      selectedModifiers.fold<double>(
        0,
        (sum, modifier) => sum + modifier.priceDelta,
      );

  double get lineTotal => singleItemPrice * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    List<SelectedModifier>? selectedModifiers,
    String? lineId,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      lineId: lineId ?? this.lineId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'product': product.toJson(),
    'quantity': quantity,
    'selectedModifiers': selectedModifiers
        .map((item) => item.toJson())
        .toList(growable: false),
    'lineId': lineId,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(
        Map<String, dynamic>.from(json['product'] as Map),
      ),
      quantity: _intValue(json['quantity'], 1),
      selectedModifiers: _readList(
        json['selectedModifiers'],
        SelectedModifier.fromJson,
      ),
      lineId: json['lineId'] as String?,
    );
  }
}

class CartLineInput {
  const CartLineInput({
    required this.lineId,
    required this.productId,
    required this.quantity,
    required this.modifierIds,
    required this.productName,
    required this.unitPrice,
    required this.modifierLabels,
    required this.lineTotal,
    this.selectedModifiers = const <SelectedModifier>[],
  });

  final String lineId;
  final String productId;
  final int quantity;
  final List<String> modifierIds;
  final String productName;
  final double unitPrice;
  final List<String> modifierLabels;
  final double lineTotal;
  final List<SelectedModifier> selectedModifiers;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lineId': lineId,
    'productId': productId,
    'quantity': quantity,
    'modifierIds': modifierIds,
    'productName': productName,
    'unitPrice': unitPrice,
    'modifierLabels': modifierLabels,
    'lineTotal': lineTotal,
    'selectedModifiers': selectedModifiers
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  factory CartLineInput.fromJson(Map<String, dynamic> json) {
    return CartLineInput(
      lineId: json['lineId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      quantity: _intValue(json['quantity'], 1),
      modifierIds: _readStringList(json['modifierIds']),
      productName: json['productName'] as String? ?? '',
      unitPrice: _numValue(json['unitPrice']),
      modifierLabels: _readStringList(json['modifierLabels']),
      lineTotal: _numValue(json['lineTotal']),
      selectedModifiers: _readList(
        json['selectedModifiers'],
        SelectedModifier.fromJson,
      ),
    );
  }
}

class OrderDraft {
  const OrderDraft({
    required this.cashierName,
    required this.orderType,
    required this.paymentType,
    required this.taxRate,
    required this.serviceChargeRate,
    required this.cashReceived,
    required this.lines,
    required this.note,
    required this.shiftId,
    this.discountAmount = 0,
    this.discountApplication = const DiscountApplication.none(),
    this.vatEnabled = true,
  });

  final String cashierName;
  final String orderType;
  final PaymentType paymentType;
  final double taxRate;
  final double serviceChargeRate;
  final double cashReceived;
  final List<CartLineInput> lines;
  final String note;
  final String shiftId;
  final double discountAmount;
  final DiscountApplication discountApplication;
  final bool vatEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cashierName': cashierName,
    'orderType': orderType,
    'paymentType': paymentType.name,
    'taxRate': taxRate,
    'serviceChargeRate': serviceChargeRate,
    'cashReceived': cashReceived,
    'lines': lines.map((item) => item.toJson()).toList(growable: false),
    'note': note,
    'shiftId': shiftId,
    'discountAmount': discountAmount,
    'discountApplication': discountApplication.toJson(),
    'vatEnabled': vatEnabled,
  };

  factory OrderDraft.fromJson(Map<String, dynamic> json) {
    return OrderDraft(
      cashierName: json['cashierName'] as String? ?? '',
      orderType: json['orderType'] as String? ?? 'Dine-in',
      paymentType: _enumFromName(
        PaymentType.values,
        json['paymentType'] as String?,
        PaymentType.cash,
      ),
      taxRate: _numValue(json['taxRate']),
      serviceChargeRate: _numValue(json['serviceChargeRate']),
      cashReceived: _numValue(json['cashReceived']),
      lines: _readList(json['lines'], CartLineInput.fromJson),
      note: json['note'] as String? ?? '',
      shiftId: json['shiftId'] as String? ?? '',
      discountAmount: _numValue(json['discountAmount']),
      discountApplication: json['discountApplication'] is Map
          ? DiscountApplication.fromJson(
              Map<String, dynamic>.from(json['discountApplication'] as Map),
            )
          : const DiscountApplication.none(),
      vatEnabled: json['vatEnabled'] as bool? ?? true,
    );
  }
}

class OrderLineSnapshot {
  const OrderLineSnapshot({
    required this.lineId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.modifierLabels,
    required this.lineTotal,
    this.selectedModifiers = const <SelectedModifier>[],
  });

  final String lineId;
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final List<String> modifierLabels;
  final double lineTotal;
  final List<SelectedModifier> selectedModifiers;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lineId': lineId,
    'productId': productId,
    'productName': productName,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'modifierLabels': modifierLabels,
    'lineTotal': lineTotal,
    'selectedModifiers': selectedModifiers
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  factory OrderLineSnapshot.fromJson(Map<String, dynamic> json) {
    return OrderLineSnapshot(
      lineId: json['lineId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      unitPrice: _numValue(json['unitPrice']),
      quantity: _intValue(json['quantity'], 1),
      modifierLabels: _readStringList(json['modifierLabels']),
      lineTotal: _numValue(json['lineTotal']),
      selectedModifiers: _readList(
        json['selectedModifiers'],
        SelectedModifier.fromJson,
      ),
    );
  }
}

class OrderTotals {
  const OrderTotals({
    required this.grossAmount,
    required this.vatableSales,
    required this.vatExemptSales,
    required this.vatExemptionAmount,
    required this.vatAmount,
    required this.seniorDiscount,
    required this.pwdDiscount,
    required this.otherDiscount,
    required this.totalDiscount,
    required this.serviceCharge,
    required this.amountDue,
    required this.discountApplication,
    required this.cashReceived,
    required this.change,
    required this.isValid,
    this.vatEnabled = true,
  });

  final double grossAmount;
  final double vatableSales;
  final double vatExemptSales;
  final double vatExemptionAmount;
  final double vatAmount;
  final double seniorDiscount;
  final double pwdDiscount;
  final double otherDiscount;
  final double totalDiscount;
  final double serviceCharge;
  final double amountDue;
  final DiscountApplication discountApplication;
  final double cashReceived;
  final double change;
  final bool isValid;
  final bool vatEnabled;

  double get subtotal => grossAmount;
  double get discount => totalDiscount;
  double get tax => vatAmount;
  double get total => amountDue;
}

class OrderQueueRecord {
  const OrderQueueRecord({
    required this.id,
    required this.sequence,
    required this.status,
    required this.customerName,
    required this.orderType,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final int sequence;
  final OrderQueueStatus status;
  final String customerName;
  final String orderType;
  final DateTime createdAt;
  final List<OrderLineSnapshot> items;

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sequence': sequence,
    'status': status.name,
    'customerName': customerName,
    'orderType': orderType,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  factory OrderQueueRecord.fromJson(Map<String, dynamic> json) {
    return OrderQueueRecord(
      id: json['id'] as String? ?? '',
      sequence: _intValue(json['sequence']),
      status: _enumFromName(
        OrderQueueStatus.values,
        json['status'] as String?,
        OrderQueueStatus.pending,
      ),
      customerName: json['customerName'] as String? ?? '',
      orderType: json['orderType'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: _readList(json['items'], OrderLineSnapshot.fromJson),
    );
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.contact,
    required this.orderCount,
    required this.totalSpent,
  });

  final String id;
  final String name;
  final String contact;
  final int orderCount;
  final double totalSpent;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'contact': contact,
    'orderCount': orderCount,
    'totalSpent': totalSpent,
  };

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      orderCount: _intValue(json['orderCount']),
      totalSpent: _numValue(json['totalSpent']),
    );
  }
}

enum OrderAction { complete, cancel, refund }

class OrderStatusChange {
  const OrderStatusChange({
    required this.action,
    required this.reason,
    required this.userId,
    required this.cashierName,
    required this.at,
    this.amount = 0,
  });
  final OrderAction action;
  final String reason;
  final String userId;
  final String cashierName;
  final DateTime at;
  final double amount;
  Map<String, dynamic> toJson() => {
    'action': action.name,
    'reason': reason,
    'userId': userId,
    'cashierName': cashierName,
    'at': at.toIso8601String(),
    'amount': amount,
  };
  factory OrderStatusChange.fromJson(Map<String, dynamic> json) =>
      OrderStatusChange(
        action: _enumFromName(
          OrderAction.values,
          json['action'] as String?,
          OrderAction.complete,
        ),
        reason: json['reason'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        cashierName: json['cashierName'] as String? ?? '',
        at:
            DateTime.tryParse(json['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        amount: _numValue(json['amount']),
      );
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.sequence,
    required this.status,
    required this.orderType,
    required this.paymentType,
    required this.cashierName,
    required this.createdAt,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.serviceCharge,
    required this.total,
    required this.cashReceived,
    required this.change,
    required this.items,
    this.grossAmount = 0,
    this.vatableSales = 0,
    this.vatExemptSales = 0,
    this.vatExemptionAmount = 0,
    this.seniorDiscount = 0,
    this.pwdDiscount = 0,
    this.otherDiscount = 0,
    this.totalDiscount = 0,
    this.discountApplication = const DiscountApplication.none(),
    this.vatEnabled = true,
    this.statusHistory = const [],
    this.originalQueue,
  });

  final List<OrderStatusChange> statusHistory;
  final OrderQueueRecord? originalQueue;

  final String id;
  final int sequence;
  final OrderStatus status;
  final String orderType;
  final PaymentType paymentType;
  final String cashierName;
  final DateTime createdAt;
  final double subtotal;
  final double discount;
  final double tax;
  final double serviceCharge;
  final double total;
  final double cashReceived;
  final double change;
  final List<OrderLineSnapshot> items;
  final double grossAmount;
  final double vatableSales;
  final double vatExemptSales;
  final double vatExemptionAmount;
  final double seniorDiscount;
  final double pwdDiscount;
  final double otherDiscount;
  final double totalDiscount;
  final DiscountApplication discountApplication;
  final bool vatEnabled;

  factory OrderRecord.fromDraft(OrderDraft draft, {required int sequence}) {
    throw UnsupportedError(
      'Use OrderRecord.fromCalculatedTotals to create order records.',
    );
  }

  factory OrderRecord.fromCalculatedTotals({
    required OrderDraft draft,
    required OrderTotals totals,
    required int sequence,
    String? id,
  }) {
    return OrderRecord(
      id: id ?? 'ORD-$sequence',
      sequence: sequence,
      status: OrderStatus.paid,
      orderType: draft.orderType,
      paymentType: draft.paymentType,
      cashierName: draft.cashierName,
      createdAt: DateTime.now(),
      subtotal: totals.subtotal,
      discount: totals.discount,
      tax: totals.tax,
      serviceCharge: totals.serviceCharge,
      total: totals.total,
      cashReceived: draft.cashReceived,
      change: totals.change,
      items: draft.lines
          .map(
            (line) => OrderLineSnapshot(
              lineId: line.lineId,
              productId: line.productId,
              productName: line.productName,
              unitPrice: line.unitPrice,
              quantity: line.quantity,
              modifierLabels: line.modifierLabels,
              lineTotal: line.lineTotal,
              selectedModifiers: line.selectedModifiers,
            ),
          )
          .toList(growable: false),
      grossAmount: totals.grossAmount,
      vatableSales: totals.vatableSales,
      vatExemptSales: totals.vatExemptSales,
      vatExemptionAmount: totals.vatExemptionAmount,
      seniorDiscount: totals.seniorDiscount,
      pwdDiscount: totals.pwdDiscount,
      otherDiscount: totals.otherDiscount,
      totalDiscount: totals.totalDiscount,
      discountApplication: totals.discountApplication,
      vatEnabled: totals.vatEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'statusHistory': statusHistory.map((entry) => entry.toJson()).toList(),
    if (originalQueue != null) 'originalQueue': originalQueue!.toJson(),
    'id': id,
    'sequence': sequence,
    'status': status.name,
    'orderType': orderType,
    'paymentType': paymentType.name,
    'cashierName': cashierName,
    'createdAt': createdAt.toIso8601String(),
    'subtotal': subtotal,
    'discount': discount,
    'tax': tax,
    'serviceCharge': serviceCharge,
    'total': total,
    'cashReceived': cashReceived,
    'change': change,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'grossAmount': grossAmount,
    'vatableSales': vatableSales,
    'vatExemptSales': vatExemptSales,
    'vatExemptionAmount': vatExemptionAmount,
    'seniorDiscount': seniorDiscount,
    'pwdDiscount': pwdDiscount,
    'otherDiscount': otherDiscount,
    'totalDiscount': totalDiscount,
    'discountApplication': discountApplication.toJson(),
    'vatEnabled': vatEnabled,
  };

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    return OrderRecord(
      statusHistory: _readList(
        json['statusHistory'],
        OrderStatusChange.fromJson,
      ),
      originalQueue: json['originalQueue'] is Map
          ? OrderQueueRecord.fromJson(
              Map<String, dynamic>.from(json['originalQueue'] as Map),
            )
          : null,
      id: json['id'] as String? ?? '',
      sequence: _intValue(json['sequence']),
      status: _enumFromName(
        OrderStatus.values,
        json['status'] as String?,
        OrderStatus.paid,
      ),
      orderType: json['orderType'] as String? ?? 'Dine-in',
      paymentType: _enumFromName(
        PaymentType.values,
        json['paymentType'] as String?,
        PaymentType.cash,
      ),
      cashierName: json['cashierName'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      subtotal: _numValue(json['subtotal']),
      discount: _numValue(json['discount']),
      tax: _numValue(json['tax']),
      serviceCharge: _numValue(json['serviceCharge']),
      total: _numValue(json['total']),
      cashReceived: _numValue(json['cashReceived']),
      change: _numValue(json['change']),
      items: _readList(json['items'], OrderLineSnapshot.fromJson),
      grossAmount: _numValue(json['grossAmount']),
      vatableSales: _numValue(json['vatableSales']),
      vatExemptSales: _numValue(json['vatExemptSales']),
      vatExemptionAmount: _numValue(json['vatExemptionAmount']),
      seniorDiscount: _numValue(json['seniorDiscount']),
      pwdDiscount: _numValue(json['pwdDiscount']),
      otherDiscount: _numValue(json['otherDiscount']),
      totalDiscount: _numValue(json['totalDiscount']),
      discountApplication: json['discountApplication'] is Map
          ? DiscountApplication.fromJson(
              Map<String, dynamic>.from(json['discountApplication'] as Map),
            )
          : const DiscountApplication.none(),
      vatEnabled:
          json['vatEnabled'] as bool? ??
          (_numValue(json['tax']) > 0 || _numValue(json['vatableSales']) > 0),
    );
  }
}

class InventoryHealth {
  const InventoryHealth({
    required this.id,
    required this.itemName,
    required this.statusLabel,
    required this.onHand,
    required this.threshold,
    required this.severity,
  });

  final String id;
  final String itemName;
  final String statusLabel;
  final int onHand;
  final int threshold;
  final InventorySeverity severity;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'itemName': itemName,
    'statusLabel': statusLabel,
    'onHand': onHand,
    'threshold': threshold,
    'severity': severity.name,
  };

  factory InventoryHealth.fromJson(Map<String, dynamic> json) {
    return InventoryHealth(
      id: json['id'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      statusLabel: json['statusLabel'] as String? ?? '',
      onHand: _intValue(json['onHand']),
      threshold: _intValue(json['threshold']),
      severity: _enumFromName(
        InventorySeverity.values,
        json['severity'] as String?,
        InventorySeverity.good,
      ),
    );
  }
}

class ShiftSummary {
  const ShiftSummary({
    required this.staffName,
    required this.openedAtText,
    required this.tillBalance,
  });

  final String staffName;
  final String openedAtText;
  final double tillBalance;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'staffName': staffName,
    'openedAtText': openedAtText,
    'tillBalance': tillBalance,
  };

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      staffName: json['staffName'] as String? ?? '',
      openedAtText: json['openedAtText'] as String? ?? '',
      tillBalance: _numValue(json['tillBalance']),
    );
  }
}

class CheckoutSummary extends OrderTotals {
  const CheckoutSummary({
    required super.grossAmount,
    required super.vatableSales,
    required super.vatExemptSales,
    required super.vatExemptionAmount,
    required super.vatAmount,
    required super.seniorDiscount,
    required super.pwdDiscount,
    required super.otherDiscount,
    required super.totalDiscount,
    required super.serviceCharge,
    required super.amountDue,
    required super.discountApplication,
    required super.cashReceived,
    required super.change,
    required super.isValid,
    super.vatEnabled = true,
  });
}

T _enumFromName<T extends Enum>(Iterable<T> values, String? name, T fallback) {
  if (name == null || name.isEmpty) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

double _numValue(Object? value, [double fallback = 0]) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return <String>[];
  }
  return value
      .whereType<Object?>()
      .map((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<T> _readList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) parser,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
