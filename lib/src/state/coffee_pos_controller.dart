import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/coffee_pos_repository.dart';
import '../domain/checkout_calculator.dart';
import '../domain/coffee_pos_models.dart';
import '../utils/receipt_printer.dart' as receipt_printer;

class CoffeePosController extends ChangeNotifier {
  CoffeePosController({required this.repository});

  final CoffeePosRepository repository;
  final CheckoutCalculator _calculator = const CheckoutCalculator();

  bool _isLoading = true;
  Role _role = Role.cashier;
  int _selectedCategoryIndex = 0;
  String? _activeProductId;
  final List<CartItem> _cart = <CartItem>[];
  StoreBootstrap? _bootstrap;
  List<Category> _categories = <Category>[];
  List<Product> _products = <Product>[];
  List<ModifierGroup> _modifierGroups = <ModifierGroup>[];
  List<InventoryHealth> _inventoryHealth = <InventoryHealth>[];
  List<OrderQueueRecord> _activeOrders = <OrderQueueRecord>[];
  List<CustomerProfile> _customers = <CustomerProfile>[];
  List<OrderRecord> _recentOrders = <OrderRecord>[];
  List<ShiftSummary> _activeShifts = <ShiftSummary>[];
  double _todaySales = 0;
  double _discountAmount = 0;
  double _taxRate = 0.12;
  double _serviceChargeRate = 0.0;
  double _cashReceived = 0;
  PaymentType _paymentType = PaymentType.card;
  String _orderType = 'Dine-in';
  String _cashierName = 'Alex';
  String? _selectedCustomerId;
  String _storeName = 'Haven & Co.';
  String _storeAddress = 'Store address not set';
  String _storeContact = 'Store contact not set';
  String _receiptHeader = 'Thank you for your order';
  String _receiptFooter = 'Visit us again soon.';
  String _currencyCode = 'PHP';
  String _currencySymbol = '₱';
  String _printerName = 'Kitchen Printer';
  String _printerUrl = '';
  bool _autoPrintReceipts = true;
  bool _compactReceiptStyle = false;
  bool _showBadges = true;
  bool _highContrastMode = false;
  final String _shiftId = 'shift-001';
  static const String _resetSnapshotPreferenceKey = 'bites_brew_reset_snapshot';
  static const String _legacyResetFlagPreferenceKey = 'bites_brew_reset_mode';
  StreamSubscription<DatabaseEvent>? _realtimeSnapshotSubscription;
  StreamSubscription<DatabaseEvent>? _sharedCatalogSubscription;
  Future<void> _persistenceQueue = Future<void>.value();
  bool _needsRealtimeDatabaseMigration = false;

  String? get _currentUserId {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String get _persistenceScope => _currentUserId ?? 'guest';
  String _scopedPreferenceKey(String key) => '$key$_persistenceScope';

  DatabaseReference? get _realtimeSnapshotReference {
    final userId = _currentUserId;
    if (userId == null) {
      return null;
    }
    return FirebaseDatabase.instance.ref('users/$userId');
  }

  DatabaseReference get _sharedCatalogReference =>
      FirebaseDatabase.instance.ref('store/catalog');

  bool get isLoading => _isLoading;
  Role get role => _role;
  int get selectedCategoryIndex => _selectedCategoryIndex;
  String? get activeProductId => _activeProductId;
  List<CartItem> get cart => List.unmodifiable(_cart);
  StoreBootstrap? get bootstrap => _bootstrap;
  double get discountAmount => _discountAmount;
  double get taxRate => _taxRate;
  double get serviceChargeRate => _serviceChargeRate;
  double get cashReceived => _cashReceived;
  PaymentType get paymentType => _paymentType;
  String get orderType => _orderType;
  String get cashierName => _cashierName;
  String? get selectedCustomerId => _selectedCustomerId;
  String get storeName => _storeName;
  String get storeAddress => _storeAddress;
  String get storeContact => _storeContact;
  String get receiptHeader => _receiptHeader;
  String get receiptFooter => _receiptFooter;
  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  String get printerName => _printerName;
  String get printerUrl => _printerUrl;
  bool get autoPrintReceipts => _autoPrintReceipts;
  bool get compactReceiptStyle => _compactReceiptStyle;
  bool get showBadges => _showBadges;
  bool get highContrastMode => _highContrastMode;
  CustomerProfile? get selectedCustomer {
    if (_selectedCustomerId == null) {
      return null;
    }
    for (final customer in _customers) {
      if (customer.id == _selectedCustomerId) {
        return customer;
      }
    }
    return null;
  }

  String get shiftId => _shiftId;

  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> get cashierCategories => List.unmodifiable(
    _categories
        .where(
          (category) =>
              _products.any((product) => product.categoryId == category.id),
        )
        .toList(growable: false),
  );
  List<Product> get products => List.unmodifiable(_products);
  List<ModifierGroup> get modifierGroups => List.unmodifiable(_modifierGroups);
  List<InventoryHealth> get inventoryHealth =>
      List.unmodifiable(_inventoryHealth);
  List<OrderQueueRecord> get activeOrders => List.unmodifiable(_activeOrders);
  List<CustomerProfile> get customers => List.unmodifiable(_customers);
  List<OrderRecord> get recentOrders => List.unmodifiable(_recentOrders);
  List<ShiftSummary> get activeShifts => List.unmodifiable(_activeShifts);
  double get todaySales => _todaySales;

  Category? get selectedCategory {
    final categories = cashierCategories;
    if (categories.isEmpty || _selectedCategoryIndex >= categories.length) {
      return null;
    }
    return categories[_selectedCategoryIndex];
  }

  List<Product> get visibleProducts {
    final category = selectedCategory;
    if (category == null) {
      return List.unmodifiable(_products);
    }
    return _products
        .where((product) => product.categoryId == category.id)
        .toList(growable: false);
  }

  CheckoutSummary get checkoutSummary => _calculator.summarize(
    cartItems: _cart,
    discountAmount: _discountAmount,
    taxRate: _taxRate,
    serviceChargeRate: _serviceChargeRate,
    cashReceived: _cashReceived,
  );

  bool get canCheckout {
    final summary = checkoutSummary;
    if (!summary.isValid) {
      return false;
    }
    if (_paymentType == PaymentType.cash) {
      return _cashReceived >= summary.total;
    }
    return true;
  }

  Future<void> initialize() async {
    await _loadAuthenticatedRole();
    // A signed-in user's Firestore state is authoritative so every device
    // starts from the same data rather than an older local cache.
    final remoteSnapshot = await _loadFirebaseStateSnapshot();
    final savedSnapshot = remoteSnapshot ?? await _loadSavedStateSnapshot();
    if (savedSnapshot != null) {
      _applyStateJson(savedSnapshot);
      final addedDefaultCategories = _ensureDefaultCategories();
      if (remoteSnapshot != null) {
        await _saveLocalStateSnapshot(savedSnapshot);
        if (_needsRealtimeDatabaseMigration || addedDefaultCategories) {
          await _saveCurrentStateSnapshot();
        }
      } else {
        // Migrate an existing on-device snapshot into Realtime Database.
        await _saveCurrentStateSnapshot();
      }
    } else {
      final bootstrap = await repository.loadBootstrap();
      _applyBootstrap(bootstrap);
      if (await _isLegacyResetModeEnabled()) {
        _applyOperationalResetState();
        await _clearLegacyResetMode();
      }
      await _saveCurrentStateSnapshot();
    }
    final sharedCatalog = await _loadSharedCatalog();
    if (sharedCatalog != null) {
      _applySharedCatalog(sharedCatalog);
    } else if (_role == Role.admin) {
      await _saveSharedCatalog();
    }
    _isLoading = false;
    _startFirebaseStateSubscription();
    _startSharedCatalogSubscription();
    notifyListeners();
  }

  Future<void> _loadAuthenticatedRole() async {
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    if (user == null) {
      _role = Role.cashier;
      return;
    }
    try {
      await FirebaseFunctions.instance
          .httpsCallable('bootstrapRole')
          .call()
          .timeout(const Duration(seconds: 5));
      final token = await user.getIdTokenResult(true);
      _role = token.claims?['role'] == 'admin' ? Role.admin : Role.cashier;
    } catch (_) {
      // A failed role lookup never grants elevated access.
      _role = Role.cashier;
    }
  }

  void _applyBootstrap(StoreBootstrap bootstrap) {
    _bootstrap = bootstrap;
    _categories = List<Category>.from(bootstrap.categories);
    _products = List<Product>.from(bootstrap.products);
    _modifierGroups = List<ModifierGroup>.from(bootstrap.modifierGroups);
    _inventoryHealth = List<InventoryHealth>.from(bootstrap.inventoryHealth);
    _activeOrders = List<OrderQueueRecord>.from(bootstrap.activeOrders);
    _customers = List<CustomerProfile>.from(bootstrap.customers);
    _recentOrders = List<OrderRecord>.from(bootstrap.recentOrders);
    _activeShifts = List<ShiftSummary>.from(bootstrap.activeShifts);
    _todaySales = bootstrap.todaySales;
  }

  Map<String, dynamic> _sharedCatalogJson() => <String, dynamic>{
    'categories': _categories.map((item) => item.toJson()).toList(),
    'products': _products.map((item) => item.toJson()).toList(),
    'modifierGroups': _modifierGroups.map((item) => item.toJson()).toList(),
    'updatedAt': ServerValue.timestamp,
  };

  void _applySharedCatalog(Map<String, dynamic> json) {
    _categories = _readRealtimeModels(json['categories'], Category.fromJson);
    _products = _readRealtimeModels(json['products'], Product.fromJson);
    _modifierGroups = _readRealtimeModels(
      json['modifierGroups'],
      ModifierGroup.fromJson,
    );
    _ensureDefaultCategories();
  }

  List<T> _readRealtimeModels<T>(
    Object? value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final values = value is List
        ? value
        : value is Map
        ? value.values.toList()
        : const <Object?>[];
    return values
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  bool _ensureDefaultCategories() {
    if (_categories.isNotEmpty) {
      return false;
    }
    _categories = List<Category>.from(StoreBootstrap.sample().categories);
    return true;
  }

  StoreBootstrap _currentBootstrap() {
    return StoreBootstrap(
      categories: List<Category>.from(_categories),
      products: List<Product>.from(_products),
      modifierGroups: List<ModifierGroup>.from(_modifierGroups),
      inventoryHealth: List<InventoryHealth>.from(_inventoryHealth),
      todaySales: _todaySales,
      recentOrders: List<OrderRecord>.from(_recentOrders),
      activeShifts: List<ShiftSummary>.from(_activeShifts),
      activeOrders: List<OrderQueueRecord>.from(_activeOrders),
      customers: List<CustomerProfile>.from(_customers),
    );
  }

  Map<String, dynamic> _settingsSnapshot() {
    return <String, dynamic>{
      'storeName': _storeName,
      'storeAddress': _storeAddress,
      'storeContact': _storeContact,
      'receiptHeader': _receiptHeader,
      'receiptFooter': _receiptFooter,
      'currencyCode': _currencyCode,
      'currencySymbol': _currencySymbol,
      'printerName': _printerName,
      'printerUrl': _printerUrl,
      'autoPrintReceipts': _autoPrintReceipts,
      'orderType': _orderType,
      'cashierName': _cashierName,
      'compactReceiptStyle': _compactReceiptStyle,
      'showBadges': _showBadges,
      'highContrastMode': _highContrastMode,
    };
  }

  void _applySettingsSnapshot(Map<String, dynamic> json) {
    _storeName = json['storeName'] as String? ?? _storeName;
    _storeAddress = json['storeAddress'] as String? ?? _storeAddress;
    _storeContact = json['storeContact'] as String? ?? _storeContact;
    _receiptHeader = json['receiptHeader'] as String? ?? _receiptHeader;
    _receiptFooter = json['receiptFooter'] as String? ?? _receiptFooter;
    _currencyCode = json['currencyCode'] as String? ?? _currencyCode;
    _currencySymbol = json['currencySymbol'] as String? ?? _currencySymbol;
    _printerName = json['printerName'] as String? ?? _printerName;
    _printerUrl = json['printerUrl'] as String? ?? _printerUrl;
    _autoPrintReceipts =
        json['autoPrintReceipts'] as bool? ?? _autoPrintReceipts;
    _orderType = json['orderType'] as String? ?? _orderType;
    _cashierName = json['cashierName'] as String? ?? _cashierName;
    _compactReceiptStyle =
        json['compactReceiptStyle'] as bool? ?? _compactReceiptStyle;
    _showBadges = json['showBadges'] as bool? ?? _showBadges;
    _highContrastMode = json['highContrastMode'] as bool? ?? _highContrastMode;
  }

  Map<String, dynamic> exportState() {
    return <String, dynamic>{
      'version': 3,
      ..._currentBootstrap().toJson(),
      'settings': _settingsSnapshot(),
      'session': <String, dynamic>{
        'cart': _cart.map((item) => item.toJson()).toList(growable: false),
        'discountAmount': _discountAmount,
        'taxRate': _taxRate,
        'serviceChargeRate': _serviceChargeRate,
        'cashReceived': _cashReceived,
        'paymentType': _paymentType.name,
        'selectedCustomerId': _selectedCustomerId,
      },
    };
  }

  String exportStateJson({bool pretty = true}) {
    final state = exportState();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(state)
        : jsonEncode(state);
  }

  void importStateJson(String jsonText) {
    _applyStateJson(jsonText);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void _applyStateJson(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    final payload = Map<String, dynamic>.from(decoded);
    final bootstrapJson = payload['bootstrap'] is Map
        ? Map<String, dynamic>.from(payload['bootstrap'] as Map)
        : payload;
    final bootstrap = StoreBootstrap.fromJson(bootstrapJson);
    _bootstrap = bootstrap;
    if (bootstrapJson.containsKey('categories')) {
      _categories = List<Category>.from(bootstrap.categories);
    }
    if (bootstrapJson.containsKey('products')) {
      _products = List<Product>.from(bootstrap.products);
    }
    if (bootstrapJson.containsKey('modifierGroups')) {
      _modifierGroups = List<ModifierGroup>.from(bootstrap.modifierGroups);
    }
    _inventoryHealth = List<InventoryHealth>.from(bootstrap.inventoryHealth);
    _activeOrders = List<OrderQueueRecord>.from(bootstrap.activeOrders);
    _customers = List<CustomerProfile>.from(bootstrap.customers);
    _recentOrders = List<OrderRecord>.from(bootstrap.recentOrders);
    _activeShifts = List<ShiftSummary>.from(bootstrap.activeShifts);
    _todaySales = bootstrap.todaySales;
    _selectedCategoryIndex = 0;
    _activeProductId = null;
    _cart.clear();
    _discountAmount = 0;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _selectedCustomerId = null;

    final settings = payload['settings'];
    if (settings is Map) {
      _applySettingsSnapshot(Map<String, dynamic>.from(settings));
    }

    final session = payload['session'];
    if (session is Map) {
      final sessionJson = Map<String, dynamic>.from(session);
      _cart
        ..clear()
        ..addAll(_readCartItems(sessionJson['cart']));
      _discountAmount = _numberFromJson(sessionJson['discountAmount']);
      _taxRate = _numberFromJson(sessionJson['taxRate'], 0.12);
      _serviceChargeRate = _numberFromJson(sessionJson['serviceChargeRate']);
      _cashReceived = _numberFromJson(sessionJson['cashReceived']);
      _paymentType = PaymentType.values.firstWhere(
        (type) => type.name == sessionJson['paymentType'],
        orElse: () => PaymentType.card,
      );
      _selectedCustomerId = sessionJson['selectedCustomerId'] as String?;
    }
  }

  List<CartItem> _readCartItems(Object? value) {
    if (value is! List) {
      return const <CartItem>[];
    }
    return value
        .whereType<Map>()
        .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  double _numberFromJson(Object? value, [double fallback = 0]) {
    return value is num ? value.toDouble() : fallback;
  }

  void replaceBootstrap(StoreBootstrap bootstrap) {
    _bootstrap = bootstrap;
    _applyBootstrap(bootstrap);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  void toggleRole(Role role) {
    // Roles are managed through Firebase custom claims, never from the client.
  }

  void selectCategory(int index) {
    final categories = cashierCategories;
    _selectedCategoryIndex = index.clamp(
      0,
      categories.isEmpty ? 0 : categories.length - 1,
    );
    notifyListeners();
  }

  void selectProduct(String productId) {
    _activeProductId = productId;
    notifyListeners();
  }

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  ModifierGroup? modifierGroupById(String id) {
    for (final group in _modifierGroups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  List<SelectedModifier> resolveDefaultModifiers(Product product) {
    final result = <SelectedModifier>[];
    for (final groupId in product.modifierGroupIds) {
      final group = modifierGroupById(groupId);
      if (group == null || group.options.isEmpty) {
        continue;
      }
      final option = group.options.first;
      result.add(
        SelectedModifier(
          groupId: group.id,
          optionId: option.id,
          label: option.name,
          priceDelta: option.priceDelta,
        ),
      );
    }
    return result;
  }

  List<String> defaultModifierGroupIdsForCategory(String categoryId) {
    switch (categoryId) {
      case 'coffee':
      case 'shakes':
        return const <String>['size', 'milk', 'extras'];
      case 'snacks':
      case 'ala-carte':
      case 'combos':
      case 'desserts':
        return const <String>[];
      default:
        return const <String>[];
    }
  }

  void addCategory({required String name, required String icon}) {
    _categories = [
      ..._categories,
      Category(id: _nextId('cat'), name: name, icon: icon),
    ];
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void ensureImportedCategory({
    required String id,
    required String name,
    required String icon,
  }) {
    if (id.isEmpty || _categories.any((category) => category.id == id)) {
      return;
    }
    _categories = [
      ..._categories,
      Category(
        id: id,
        name: name.isEmpty ? id : name,
        icon: icon.isEmpty ? '🍽️' : icon,
      ),
    ];
  }

  void updateCategory({
    required String categoryId,
    required String name,
    required String icon,
  }) {
    final index = _categories.indexWhere(
      (category) => category.id == categoryId,
    );
    if (index == -1) {
      return;
    }
    _categories[index] = Category(id: categoryId, name: name, icon: icon);
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void deleteCategory(String categoryId) {
    _categories.removeWhere((category) => category.id == categoryId);
    _products.removeWhere((product) => product.categoryId == categoryId);
    if (_selectedCategoryIndex >= _categories.length) {
      _selectedCategoryIndex = _categories.isEmpty ? 0 : _categories.length - 1;
    }
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void createProduct({
    required String name,
    required String categoryId,
    required double price,
    required String description,
    required String badge,
    List<String>? modifierGroupIds,
  }) {
    _products = [
      ..._products,
      Product(
        id: _nextId('prod'),
        name: name,
        categoryId: categoryId,
        price: price,
        description: description,
        badge: badge,
        modifierGroupIds:
            modifierGroupIds ?? defaultModifierGroupIdsForCategory(categoryId),
      ),
    ];
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void updateProduct({
    required String productId,
    required String name,
    required String categoryId,
    required double price,
    required String description,
    required String badge,
    List<String>? modifierGroupIds,
  }) {
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) {
      return;
    }
    _products[index] = Product(
      id: productId,
      name: name,
      categoryId: categoryId,
      price: price,
      description: description,
      badge: badge,
      modifierGroupIds:
          modifierGroupIds ?? defaultModifierGroupIdsForCategory(categoryId),
    );
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void deleteProduct(String productId) {
    _products.removeWhere((product) => product.id == productId);
    _cart.removeWhere((item) => item.product.id == productId);
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void replaceProducts(List<Product> products) {
    final productById = <String, Product>{
      for (final product in products) product.id: product,
    };
    _products = List<Product>.from(products);
    final updatedCart = <CartItem>[];
    for (final item in _cart) {
      final product = productById[item.product.id];
      if (product == null) {
        continue;
      }
      updatedCart.add(item.copyWith(product: product));
    }
    _cart
      ..clear()
      ..addAll(updatedCart);
    if (_activeProductId != null &&
        !productById.containsKey(_activeProductId)) {
      _activeProductId = null;
    }
    final categories = cashierCategories;
    if (_selectedCategoryIndex >= categories.length) {
      _selectedCategoryIndex = categories.isEmpty ? 0 : categories.length - 1;
    }
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void addInventoryItem({
    required String itemName,
    required String statusLabel,
    required int onHand,
    required int threshold,
    required InventorySeverity severity,
  }) {
    _inventoryHealth = [
      ..._inventoryHealth,
      InventoryHealth(
        id: _nextId('inv'),
        itemName: itemName,
        statusLabel: statusLabel,
        onHand: onHand,
        threshold: threshold,
        severity: severity,
      ),
    ];
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateInventoryItem({
    required String itemId,
    required String itemName,
    required String statusLabel,
    required int onHand,
    required int threshold,
    required InventorySeverity severity,
  }) {
    final index = _inventoryHealth.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    _inventoryHealth[index] = InventoryHealth(
      id: itemId,
      itemName: itemName,
      statusLabel: statusLabel,
      onHand: onHand,
      threshold: threshold,
      severity: severity,
    );
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void deleteInventoryItem(String itemId) {
    _inventoryHealth.removeWhere((item) => item.id == itemId);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void replaceInventoryItems(List<InventoryHealth> items) {
    _inventoryHealth = List<InventoryHealth>.from(items);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void addProductToCart(
    Product product, {
    List<SelectedModifier>? selectedModifiers,
    int quantity = 1,
  }) {
    if (quantity <= 0) {
      return;
    }
    final modifiers = selectedModifiers ?? resolveDefaultModifiers(product);
    final existingIndex = _cart.indexWhere(
      (item) =>
          item.product.id == product.id &&
          _modifierSignature(item.selectedModifiers) ==
              _modifierSignature(modifiers),
    );
    if (existingIndex == -1) {
      _cart.add(
        CartItem(
          product: product,
          quantity: quantity,
          selectedModifiers: modifiers,
          lineId: _nextId('line'),
        ),
      );
    } else {
      final existing = _cart[existingIndex];
      _cart[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    }
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void addProduct(Product product) => addProductToCart(product);

  void setCartQuantity(String productId, int quantity) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }
    setCartItemQuantity(_cart[index].lineId ?? productId, quantity);
  }

  void setCartItemQuantity(String lineId, int quantity) {
    final index = _cart.indexWhere((item) => item.lineId == lineId);
    if (index == -1) {
      return;
    }
    if (quantity <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = _cart[index].copyWith(quantity: quantity);
    }
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void removeFromCart(String productId) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }
    removeCartItem(_cart[index].lineId ?? productId);
  }

  void removeCartItem(String lineId) {
    _cart.removeWhere((item) => item.lineId == lineId);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateCartItemModifiers(
    String lineId,
    List<SelectedModifier> selectedModifiers,
  ) {
    final index = _cart.indexWhere((item) => item.lineId == lineId);
    if (index == -1) {
      return;
    }
    _cart[index] = _cart[index].copyWith(selectedModifiers: selectedModifiers);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void clearCart({bool persist = true}) {
    _cart.clear();
    _discountAmount = 0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _orderType = 'Dine-in';
    if (persist) {
      unawaited(_saveCurrentStateSnapshot());
    }
    notifyListeners();
  }

  void selectCustomer(String? customerId) {
    _selectedCustomerId = customerId;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void resumeOrder(OrderQueueRecord order) {
    _cart.clear();
    for (final line in order.items) {
      final product = productById(line.productId);
      if (product == null) {
        continue;
      }
      _cart.add(
        CartItem(
          product: product,
          quantity: line.quantity,
          selectedModifiers: resolveDefaultModifiers(product),
          lineId: _nextId('line'),
        ),
      );
    }
    _discountAmount = 0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _orderType = order.orderType.isEmpty ? 'Dine-in' : order.orderType;
    _activeOrders.removeWhere((item) => item.id == order.id);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void completeOrder(OrderQueueRecord order) {
    _activeOrders.removeWhere((item) => item.id == order.id);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateDiscount(double value) {
    _discountAmount = value.clamp(0, double.infinity);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateTaxRate(double value) {
    _taxRate = value.clamp(0, 1);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateServiceChargeRate(double value) {
    _serviceChargeRate = value.clamp(0, 1);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateCashReceived(double value) {
    _cashReceived = value.clamp(0, double.infinity);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updatePaymentType(PaymentType paymentType) {
    _paymentType = paymentType;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateOrderType(String orderType) {
    final normalized = orderType.trim().toLowerCase();
    _orderType = normalized == 'take-out' || normalized == 'takeout'
        ? 'Take-out'
        : 'Dine-in';
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateCashierName(String value) {
    _cashierName = value.trim().isEmpty ? 'Alex' : value.trim();
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateStoreInformation({
    required String name,
    required String address,
    required String contact,
  }) {
    _storeName = name.trim().isEmpty ? _storeName : name.trim();
    _storeAddress = address.trim().isEmpty ? _storeAddress : address.trim();
    _storeContact = contact.trim().isEmpty ? _storeContact : contact.trim();
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateReceiptSettings({required String header, required String footer}) {
    _receiptHeader = header.trim().isEmpty ? _receiptHeader : header.trim();
    _receiptFooter = footer.trim().isEmpty ? _receiptFooter : footer.trim();
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateCurrencySettings({required String code, required String symbol}) {
    _currencyCode = code.trim().isEmpty ? _currencyCode : code.trim();
    _currencySymbol = symbol.trim().isEmpty ? _currencySymbol : symbol.trim();
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updatePrinterSettings({
    required String printerName,
    required String printerUrl,
    required bool autoPrintReceipts,
  }) {
    _printerName = printerName.trim().isEmpty
        ? _printerName
        : printerName.trim();
    _printerUrl = printerUrl.trim();
    _autoPrintReceipts = autoPrintReceipts;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updatePreferences({
    required bool compactReceiptStyle,
    required bool showBadges,
    required bool highContrastMode,
  }) {
    _compactReceiptStyle = compactReceiptStyle;
    _showBadges = showBadges;
    _highContrastMode = highContrastMode;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  Future<void> resetAllData() async {
    _applyOperationalResetState();
    await _saveCurrentStateSnapshot();
    notifyListeners();
  }

  Future<void> restoreDemoData() async {
    final bootstrap = await repository.loadBootstrap();
    _applyBootstrap(bootstrap);
    _selectedCategoryIndex = 0;
    _activeProductId = null;
    _cart.clear();
    _discountAmount = 0;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _cashierName = 'Alex';
    _selectedCustomerId = null;
    _storeName = 'Haven & Co.';
    _storeAddress = 'Store address not set';
    _storeContact = 'Store contact not set';
    _receiptHeader = 'Thank you for your order';
    _receiptFooter = 'Visit us again soon.';
    _currencyCode = 'PHP';
    _currencySymbol = '₱';
    _printerName = 'Kitchen Printer';
    _autoPrintReceipts = true;
    _compactReceiptStyle = false;
    _showBadges = true;
    _highContrastMode = false;
    await _clearSavedStateSnapshot();
    notifyListeners();
  }

  Future<void> deleteAllData() async {
    final preservedCategories = List<Category>.from(_categories);
    final preservedProducts = List<Product>.from(_products);
    final preservedModifierGroups = List<ModifierGroup>.from(_modifierGroups);
    _bootstrap = StoreBootstrap(
      categories: preservedCategories,
      products: preservedProducts,
      modifierGroups: preservedModifierGroups,
      inventoryHealth: <InventoryHealth>[],
      todaySales: 0,
      recentOrders: <OrderRecord>[],
      activeShifts: <ShiftSummary>[],
      activeOrders: <OrderQueueRecord>[],
      customers: <CustomerProfile>[],
    );
    _categories = preservedCategories;
    _products = preservedProducts;
    _modifierGroups = preservedModifierGroups;
    _inventoryHealth = <InventoryHealth>[];
    _activeOrders = <OrderQueueRecord>[];
    _customers = <CustomerProfile>[];
    _recentOrders = <OrderRecord>[];
    _activeShifts = <ShiftSummary>[];
    _todaySales = 0;
    _selectedCategoryIndex = 0;
    _activeProductId = null;
    _cart.clear();
    _discountAmount = 0;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _cashierName = 'Alex';
    _selectedCustomerId = null;
    _storeName = 'Haven & Co.';
    _storeAddress = 'Store address not set';
    _storeContact = 'Store contact not set';
    _receiptHeader = 'Thank you for your order';
    _receiptFooter = 'Visit us again soon.';
    _currencyCode = 'PHP';
    _currencySymbol = '₱';
    _printerName = 'Kitchen Printer';
    _autoPrintReceipts = true;
    _compactReceiptStyle = false;
    _showBadges = true;
    _highContrastMode = false;
    await _saveCurrentStateSnapshot();
    notifyListeners();
  }

  void _applyOperationalResetState() {
    _activeOrders = <OrderQueueRecord>[];
    _recentOrders = <OrderRecord>[];
    _activeShifts = <ShiftSummary>[];
    _todaySales = 0;
    _selectedCategoryIndex = 0;
    _activeProductId = null;
    _cart.clear();
    _discountAmount = 0;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _cashierName = 'Alex';
    _selectedCustomerId = null;
    _storeName = 'Haven & Co.';
    _storeAddress = 'Store address not set';
    _storeContact = 'Store contact not set';
    _receiptHeader = 'Thank you for your order';
    _receiptFooter = 'Visit us again soon.';
    _currencyCode = 'PHP';
    _currencySymbol = '₱';
    _printerName = 'Kitchen Printer';
    _autoPrintReceipts = true;
    _compactReceiptStyle = false;
    _showBadges = true;
    _highContrastMode = false;
  }

  Future<String?> _loadSavedStateSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      final scopedKey = _scopedPreferenceKey(_resetSnapshotPreferenceKey);
      final snapshot = prefs.getString(scopedKey);
      if (snapshot != null) {
        return snapshot;
      }
      final legacySnapshot = prefs.getString(_resetSnapshotPreferenceKey);
      if (legacySnapshot != null) {
        await prefs
            .setString(scopedKey, legacySnapshot)
            .timeout(const Duration(seconds: 2));
        return legacySnapshot;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isLegacyResetModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      final scopedKey = _scopedPreferenceKey(_legacyResetFlagPreferenceKey);
      return prefs.getBool(scopedKey) ??
          prefs.getBool(_legacyResetFlagPreferenceKey) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveCurrentStateSnapshot() async {
    final snapshot = exportStateJson(pretty: false);
    _persistenceQueue = _persistenceQueue.then(
      (_) => _persistStateSnapshot(snapshot),
      onError: (_) => _persistStateSnapshot(snapshot),
    );
    return _persistenceQueue;
  }

  /// Waits for all state changes already queued for local and cloud storage.
  /// This is used before sign-out so a recent edit is not lost mid-sync.
  Future<void> flushPersistence() => _persistenceQueue;

  Future<void> _persistStateSnapshot(String snapshot) async {
    await _saveLocalStateSnapshot(snapshot);
    await _saveFirebaseStateSnapshot(snapshot);
  }

  Future<void> _saveLocalStateSnapshot(String snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs
          .setString(
            _scopedPreferenceKey(_resetSnapshotPreferenceKey),
            snapshot,
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore persistence failures; the in-memory state still applies.
    }
  }

  void _startFirebaseStateSubscription() {
    _realtimeSnapshotSubscription?.cancel();
    final reference = _realtimeSnapshotReference;
    if (reference == null) {
      return;
    }
    _realtimeSnapshotSubscription = reference.onValue.listen((event) {
      final snapshot = _stateJsonFromRealtimeValue(event.snapshot.value);
      if (snapshot == null || snapshot == exportStateJson(pretty: false)) {
        return;
      }
      try {
        _applyStateJson(snapshot);
        unawaited(_saveLocalStateSnapshot(snapshot));
        notifyListeners();
      } on FormatException {
        // Leave the current in-memory state intact when data is malformed.
      }
    });
  }

  Future<Map<String, dynamic>?> _loadSharedCatalog() async {
    if (Firebase.apps.isEmpty || _currentUserId == null) {
      return null;
    }
    try {
      final event = await _sharedCatalogReference.once().timeout(
        const Duration(seconds: 3),
      );
      final value = event.snapshot.value;
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  void _startSharedCatalogSubscription() {
    _sharedCatalogSubscription?.cancel();
    if (Firebase.apps.isEmpty || _currentUserId == null) {
      return;
    }
    _sharedCatalogSubscription = _sharedCatalogReference.onValue.listen((
      event,
    ) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return;
      }
      _applySharedCatalog(Map<String, dynamic>.from(value));
      notifyListeners();
    });
  }

  Future<void> _saveSharedCatalog() async {
    if (Firebase.apps.isEmpty ||
        _currentUserId == null ||
        _role != Role.admin) {
      return;
    }
    try {
      await _sharedCatalogReference
          .set(_sharedCatalogJson())
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // The local state remains available if the shared write fails.
    }
  }

  Future<void> _clearSavedStateSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs
          .remove(_scopedPreferenceKey(_resetSnapshotPreferenceKey))
          .timeout(const Duration(seconds: 2));
      await prefs
          .remove(_resetSnapshotPreferenceKey)
          .timeout(const Duration(seconds: 2));
      await prefs
          .remove(_scopedPreferenceKey(_legacyResetFlagPreferenceKey))
          .timeout(const Duration(seconds: 2));
      await prefs
          .remove(_legacyResetFlagPreferenceKey)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore cleanup failures.
    }
    unawaited(_clearFirebaseStateSnapshot());
  }

  Future<void> _clearLegacyResetMode() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs
          .remove(_scopedPreferenceKey(_legacyResetFlagPreferenceKey))
          .timeout(const Duration(seconds: 2));
      await prefs
          .remove(_legacyResetFlagPreferenceKey)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore migration failures.
    }
  }

  Future<String?> _loadFirebaseStateSnapshot() async {
    final reference = _realtimeSnapshotReference;
    if (Firebase.apps.isEmpty || reference == null) {
      return null;
    }
    try {
      final event = await reference.once().timeout(const Duration(seconds: 3));
      final data = event.snapshot.value;
      _needsRealtimeDatabaseMigration =
          data is Map && data['snapshot'] is String;
      return _stateJsonFromRealtimeValue(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveFirebaseStateSnapshot(String snapshot) async {
    final reference = _realtimeSnapshotReference;
    if (Firebase.apps.isEmpty || reference == null) {
      return;
    }
    try {
      final decoded = jsonDecode(snapshot);
      if (decoded is! Map) {
        return;
      }
      final state = Map<String, dynamic>.from(decoded)
        ..['updatedAt'] = ServerValue.timestamp;
      // The menu is store-wide and is persisted separately at store/catalog.
      state
        ..remove('categories')
        ..remove('products')
        ..remove('modifierGroups');
      await reference.set(state).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Ignore remote persistence failures; the local snapshot is still saved.
    }
  }

  Future<void> _clearFirebaseStateSnapshot() async {
    final reference = _realtimeSnapshotReference;
    if (Firebase.apps.isEmpty || reference == null) {
      return;
    }
    try {
      await reference.remove().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Ignore remote cleanup failures.
    }
  }

  String? _stateJsonFromRealtimeValue(Object? value) {
    if (value is! Map) {
      return null;
    }
    final state = Map<String, dynamic>.from(value);
    final legacySnapshot = state['snapshot'];
    if (legacySnapshot is String && legacySnapshot.isNotEmpty) {
      return legacySnapshot;
    }
    state.remove('updatedAt');
    return state.isEmpty ? null : jsonEncode(state);
  }

  String _modifierSignature(List<SelectedModifier> modifiers) {
    return modifiers
        .map((modifier) => '${modifier.groupId}:${modifier.optionId}')
        .join('|');
  }

  Future<OrderRecord?> checkout() async {
    if (!canCheckout) {
      return null;
    }

    final draft = OrderDraft(
      cashierName: _cashierName,
      orderType: _orderType,
      paymentType: _paymentType,
      discountAmount: _discountAmount,
      taxRate: _taxRate,
      serviceChargeRate: _serviceChargeRate,
      cashReceived: _cashReceived,
      lines: _cart
          .map(
            (item) => CartLineInput(
              lineId: item.lineId ?? item.product.id,
              productId: item.product.id,
              quantity: item.quantity,
              modifierIds: item.selectedModifiers
                  .map((modifier) => modifier.optionId)
                  .toList(growable: false),
              productName: item.product.name,
              unitPrice: item.singleItemPrice,
              modifierLabels: item.selectedModifiers
                  .map((modifier) => modifier.label)
                  .toList(growable: false),
              lineTotal: item.lineTotal,
            ),
          )
          .toList(growable: false),
      note: 'Prototype checkout',
      shiftId: _shiftId,
    );

    final order = await repository.createOrder(draft);
    _recentOrders = [order, ..._recentOrders];
    _activeOrders = [
      OrderQueueRecord(
        id: 'Q-${order.sequence}',
        sequence: order.sequence,
        status: OrderQueueStatus.preparing,
        customerName: selectedCustomer?.name ?? 'Walk-in',
        orderType: _orderType,
        createdAt: order.createdAt,
        items: order.items,
      ),
      ..._activeOrders,
    ];
    _todaySales += order.total;
    clearCart(persist: false);
    await _saveCurrentStateSnapshot();
    notifyListeners();
    return order;
  }

  Future<void> printReceipt(OrderRecord order) async {
    await receipt_printer.printReceipt(
      order: order,
      storeName: _storeName,
      storeAddress: _storeAddress,
      storeContact: _storeContact,
      receiptHeader: _receiptHeader,
      receiptFooter: _receiptFooter,
      printerName: _printerName,
      printerUrl: _printerUrl,
      compactReceiptStyle: _compactReceiptStyle,
    );
  }

  @override
  void dispose() {
    _realtimeSnapshotSubscription?.cancel();
    _sharedCatalogSubscription?.cancel();
    super.dispose();
  }
}

class CoffeePosScope extends InheritedNotifier<CoffeePosController> {
  const CoffeePosScope({
    super.key,
    required CoffeePosController controller,
    required super.child,
  }) : super(notifier: controller);

  static CoffeePosController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CoffeePosScope>();
    assert(scope != null, 'CoffeePosScope not found in context');
    return scope!.notifier!;
  }
}
