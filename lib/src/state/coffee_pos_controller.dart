import '../domain/order_lifecycle.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:printing/printing.dart';

import '../data/coffee_pos_repository.dart';
import '../domain/checkout_calculator.dart';
import '../domain/coffee_pos_models.dart';
import '../utils/printing/platform_adapters/printer_resolver.dart';
import '../utils/receipt_printer.dart' as receipt_printer;

class CoffeePosController extends ChangeNotifier {
  CoffeePosController({
    required this.repository,
    this.isDemo = false,
  });

  final CoffeePosRepository repository;
  final bool isDemo;
  final CheckoutCalculator _calculator = const CheckoutCalculator();

  bool _isLoading = true;
  Role _role = Role.cashier;
  int _selectedCategoryIndex = 0;
  int _newOrderRevision = 0;
  // Device-local browsing state: account/cart synchronization must not reset it.
  double productsScrollOffset = 0;
  double categoriesScrollOffset = 0;
  String productsSearchQuery = '';
  int get newOrderRevision => _newOrderRevision;
  void _resetProductsForNextOrder() {
    _selectedCategoryIndex = 0;
    _activeProductId = null;
    productsScrollOffset = 0;
    categoriesScrollOffset = 0;
    productsSearchQuery = '';
    _selectedCustomerId = null;
    _newOrderRevision++;
  }

  void _restoreSelectedCategory(String? id) {
    final categories = cashierCategories;
    final index = categories.indexWhere((category) => category.id == id);
    _selectedCategoryIndex = index >= 0
        ? index
        : _selectedCategoryIndex.clamp(
            0,
            categories.isEmpty ? 0 : categories.length - 1,
          );
  }

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
  bool _discountsEnabled = false;
  List<DiscountOption> _discountOptions = List.of(DiscountOption.defaults);
  String? _selectedDiscountId;
  bool _vatEnabled = true;
  double _taxRate = 0.12;
  double _serviceChargeRate = 0.0;
  double _cashReceived = 0;
  PaymentType _paymentType = PaymentType.card;
  String _orderType = 'Dine-in';
  String _cashierName = 'Alex';
  String? _selectedCustomerId;
  String _storeName = 'LUNAN';
  String _storeAddress = 'Store address not set';
  String _storeContact = 'Store contact not set';
  String _receiptHeader = 'May lugar ka rito.';
  String _receiptFooter = 'Visit us again soon.';
  String _currencyCode = 'PHP';
  String _currencySymbol = '₱';
  String _printerName = 'GEZHI_micro_printer';
  String _printerUrl = '';
  String _kitchenPrinterName = '';
  String _kitchenPrinterUrl = '';
  bool _autoPrintReceipts = true;
  String _thermalTransport = 'Direct print (no prompt)';
  bool _thermalWebKiosk = false;
  int _thermalPaperWidth = 80;
  int _thermalFeedLines = 2;
  bool _thermalAutoCut = true;
  bool _thermalOpenCashDrawer = false;
  bool _compactReceiptStyle = false;
  bool _showBadges = true;
  bool _highContrastMode = false;
  bool _isCheckingOut = false;
  final String _shiftId = 'shift-001';
  static const String _resetSnapshotPreferenceKey = 'bites_brew_reset_snapshot';
  static const String _legacyResetFlagPreferenceKey = 'bites_brew_reset_mode';
  StreamSubscription<DatabaseEvent>? _realtimeSnapshotSubscription;
  StreamSubscription<DatabaseEvent>? _sharedCatalogSubscription;
  StreamSubscription<DatabaseEvent>? _sharedOrdersSubscription;
  Future<void> _persistenceQueue = Future<void>.value();
  bool _needsRealtimeDatabaseMigration = false;

  String? get _currentUserId {
    if (isDemo) {
      return null;
    }
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String get _persistenceScope => isDemo ? 'demo_scope' : (_currentUserId ?? 'guest');
  String _scopedPreferenceKey(String key) => isDemo ? 'demo_storage_$key' : '$key$_persistenceScope';

  DatabaseReference? get _realtimeSnapshotReference {
    if (isDemo) {
      return null;
    }
    final userId = _currentUserId;
    if (userId == null) {
      return null;
    }
    return FirebaseDatabase.instance.ref('users/$userId');
  }

  DatabaseReference get _sharedCatalogReference =>
      FirebaseDatabase.instance.ref('store/catalog');

  DatabaseReference get _sharedOrdersReference =>
      FirebaseDatabase.instance.ref('store/orders');

  DatabaseReference get _customerOrdersReference =>
      FirebaseDatabase.instance.ref('customer_orders');

  bool get isLoading => _isLoading;
  bool get isCheckingOut => _isCheckingOut;
  Role get role => isDemo ? Role.admin : _role;
  int get selectedCategoryIndex => _selectedCategoryIndex;
  String? get activeProductId => _activeProductId;
  List<CartItem> get cart => List.unmodifiable(_cart);
  StoreBootstrap? get bootstrap => _bootstrap;
  double get discountAmount => _discountAmount;
  bool get discountsEnabled => _discountsEnabled;
  List<DiscountOption> get discountOptions =>
      List.unmodifiable(_discountOptions);
  List<DiscountOption> get availableDiscounts => _discountsEnabled
      ? _discountOptions.where((option) => option.enabled).toList()
      : const [];
  String? get selectedDiscountId =>
      availableDiscounts.any((option) => option.id == _selectedDiscountId)
      ? _selectedDiscountId
      : null;
  DiscountApplication get discountApplication {
    for (final option in availableDiscounts) {
      if (option.id == _selectedDiscountId) {
        return DiscountApplication(
          type: option.type,
          label: option.name,
          percentage: option.type == DiscountType.percentage
              ? option.value / 100
              : 0,
          fixedAmount: option.type == DiscountType.fixedAmount
              ? option.value
              : 0,
        );
      }
    }
    return const DiscountApplication.none();
  }

  bool get vatEnabled => _vatEnabled;
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
  String get kitchenPrinterName => _kitchenPrinterName;
  String get kitchenPrinterUrl => _kitchenPrinterUrl;
  bool get autoPrintReceipts => _autoPrintReceipts;
  String get thermalTransport => _thermalTransport;
  bool get thermalWebKiosk => _thermalWebKiosk;
  int get thermalPaperWidth => _thermalPaperWidth;
  int get thermalFeedLines => _thermalFeedLines;
  bool get thermalAutoCut => _thermalAutoCut;
  bool get thermalOpenCashDrawer => _thermalOpenCashDrawer;
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
  Category? categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }
  List<Category> get cashierCategories => List.unmodifiable(
    _categories
        .where(
          (category) =>
              _products.any((product) => product.categoryId == category.id),
        )
        .toList(growable: false),
  );
  List<Product> get products => List.unmodifiable(_products);

  /// Returns the configured modifier groups.
  List<ModifierGroup> get modifierGroups {
    if (_modifierGroups.isEmpty) {
      _modifierGroups = List<ModifierGroup>.from(StoreBootstrap.sample().modifierGroups);
    }
    return List.unmodifiable(_modifierGroups);
  }

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
    discountApplication: discountApplication,
    taxRate: _taxRate,
    serviceChargeRate: _serviceChargeRate,
    cashReceived: _cashReceived,
    vatEnabled: _vatEnabled,
  );

  bool get canCheckout {
    if (_isCheckingOut) {
      return false;
    }
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
    if (isDemo) {
      _role = Role.admin;
      final savedSnapshot = await _loadSavedStateSnapshot();
      if (savedSnapshot != null) {
        _applyStateJson(savedSnapshot);
        _ensureDefaultCategories();
      } else {
        final bootstrap = StoreBootstrap.demo();
        _applyBootstrap(bootstrap);
        await _saveLocalStateSnapshot(exportStateJson(pretty: false));
      }
      _isLoading = false;
      notifyListeners();
      return;
    }

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
    final sharedOrders = await _loadSharedOrders();
    if (sharedOrders != null) {
      _applySharedOrders(sharedOrders);
      await _saveLocalStateSnapshot(exportStateJson(pretty: false));
    } else {
      await _saveSharedOrders();
    }
    // Auto-configure thermal printer if running with demo/legacy defaults
    if (_printerName == 'Kitchen Printer' ||
        _printerName == 'GEZHI_micro_printer' ||
        _printerName.isEmpty ||
        _thermalTransport == 'System dialog') {
      await autoConfigurePrinter();
    }
    _isLoading = false;
    _startFirebaseStateSubscription();
    _startSharedCatalogSubscription();
    _startSharedOrdersSubscription();
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

  Map<String, dynamic> _sharedOrdersJson() => <String, dynamic>{
    'recentOrders': _recentOrders.map((item) => item.toJson()).toList(),
    'activeOrders': _activeOrders.map((item) => item.toJson()).toList(),
    'todaySales': _todaySales,
    'updatedAt': ServerValue.timestamp,
  };

  void _applySharedCatalog(Map<String, dynamic> json) {
    final categoryId = selectedCategory?.id;
    _categories = _readRealtimeModels(json['categories'], Category.fromJson);
    _products = _readRealtimeModels(json['products'], Product.fromJson);
    _modifierGroups = _readRealtimeModels(
      json['modifierGroups'],
      ModifierGroup.fromJson,
    );
    _ensureDefaultCategories();
    _restoreSelectedCategory(categoryId);
  }

  void _applySharedOrders(Map<String, dynamic> json) {
    _recentOrders = _readRealtimeModels(
      json['recentOrders'],
      OrderRecord.fromJson,
    );
    _activeOrders = _readRealtimeModels(
      json['activeOrders'],
      OrderQueueRecord.fromJson,
    );
    _todaySales = _numberFromJson(json['todaySales']);
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
      'discountsEnabled': _discountsEnabled,
      'discountOptions': _discountOptions
          .map((option) => option.toJson())
          .toList(),
      'storeName': _storeName,
      'storeAddress': _storeAddress,
      'storeContact': _storeContact,
      'receiptHeader': _receiptHeader,
      'receiptFooter': _receiptFooter,
      'currencyCode': _currencyCode,
      'currencySymbol': _currencySymbol,
      'printerName': _printerName,
      'printerUrl': _printerUrl,
      'kitchenPrinterName': _kitchenPrinterName,
      'kitchenPrinterUrl': _kitchenPrinterUrl,
      'autoPrintReceipts': _autoPrintReceipts,
      'thermalTransport': _thermalTransport,
      'thermalWebKiosk': _thermalWebKiosk,
      'thermalPaperWidth': _thermalPaperWidth,
      'thermalFeedLines': _thermalFeedLines,
      'thermalAutoCut': _thermalAutoCut,
      'thermalOpenCashDrawer': _thermalOpenCashDrawer,
      'orderType': _orderType,
      'cashierName': _cashierName,
      'compactReceiptStyle': _compactReceiptStyle,
      'showBadges': _showBadges,
      'highContrastMode': _highContrastMode,
      'vatEnabled': _vatEnabled,
      'taxRate': _taxRate,
      'serviceChargeRate': _serviceChargeRate,
    };
  }

  void _applySettingsSnapshot(Map<String, dynamic> json) {
    _discountsEnabled = json['discountsEnabled'] as bool? ?? false;
    _discountOptions = json['discountOptions'] is List
        ? (json['discountOptions'] as List)
              .map(
                (item) => DiscountOption.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : List.of(DiscountOption.defaults);
    _storeName = json['storeName'] as String? ?? _storeName;
    _storeAddress = json['storeAddress'] as String? ?? _storeAddress;
    _storeContact = json['storeContact'] as String? ?? _storeContact;
    _receiptHeader = json['receiptHeader'] as String? ?? _receiptHeader;
    _receiptFooter = json['receiptFooter'] as String? ?? _receiptFooter;
    _currencyCode = json['currencyCode'] as String? ?? _currencyCode;
    _currencySymbol = json['currencySymbol'] as String? ?? _currencySymbol;
    final loadedPrinterName = json['printerName'] as String?;
    _printerName =
        (loadedPrinterName == null || loadedPrinterName == 'Kitchen Printer')
        ? 'GEZHI_micro_printer'
        : loadedPrinterName;
    _printerUrl = json['printerUrl'] as String? ?? _printerUrl;
    _kitchenPrinterName =
        json['kitchenPrinterName'] as String? ?? _kitchenPrinterName;
    _kitchenPrinterUrl =
        json['kitchenPrinterUrl'] as String? ?? _kitchenPrinterUrl;
    _autoPrintReceipts =
        json['autoPrintReceipts'] as bool? ?? _autoPrintReceipts;
    final loadedTransport = json['thermalTransport'] as String?;
    _thermalTransport = loadedTransport ?? _thermalTransport;
    _thermalWebKiosk = json['thermalWebKiosk'] as bool? ?? _thermalWebKiosk;
    final savedPaperWidth = json['thermalPaperWidth'] as int?;
    _thermalPaperWidth = switch (savedPaperWidth) {
      50 || 58 || 80 =>
        (_printerName == 'GEZHI_micro_printer' && savedPaperWidth == 50)
            ? 80
            : savedPaperWidth!,
      _ => _thermalPaperWidth,
    };
    _thermalFeedLines = json['thermalFeedLines'] as int? ?? _thermalFeedLines;
    _thermalAutoCut = json['thermalAutoCut'] as bool? ?? _thermalAutoCut;
    _thermalOpenCashDrawer =
        json['thermalOpenCashDrawer'] as bool? ?? _thermalOpenCashDrawer;
    _orderType = json['orderType'] as String? ?? _orderType;
    _cashierName = json['cashierName'] as String? ?? _cashierName;
    _compactReceiptStyle =
        json['compactReceiptStyle'] as bool? ?? _compactReceiptStyle;
    _showBadges = json['showBadges'] as bool? ?? _showBadges;
    _highContrastMode = json['highContrastMode'] as bool? ?? _highContrastMode;
    _vatEnabled = json['vatEnabled'] as bool? ?? _vatEnabled;
    _taxRate = (json['taxRate'] as num?)?.toDouble() ?? _taxRate;
    _serviceChargeRate =
        (json['serviceChargeRate'] as num?)?.toDouble() ?? _serviceChargeRate;
  }

  Map<String, dynamic> exportState() {
    return <String, dynamic>{
      'version': 3,
      ..._currentBootstrap().toJson(),
      'settings': _settingsSnapshot(),
      'session': <String, dynamic>{
        'cart': _cart.map((item) => item.toJson()).toList(growable: false),
        'discountAmount': _discountAmount,
        'selectedDiscountId': selectedDiscountId,
        'vatEnabled': _vatEnabled,
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
    final categoryId = selectedCategory?.id;
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
    _restoreSelectedCategory(categoryId);
    _activeProductId = null;
    _cart.clear();
    _discountAmount = 0;
    _selectedDiscountId = null;
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
      _selectedDiscountId = sessionJson['selectedDiscountId'] as String?;
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
    for (final group in modifierGroups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  List<ModifierGroup> modifierGroupsForProduct(Product product) {
    final activeGroups = modifierGroups.where((group) => group.enabled).toList();
    final result = <ModifierGroup>[];
    final categoryDefaultIds = defaultModifierGroupIdsForCategory(product.categoryId);

    for (final group in activeGroups) {
      final directlyAssigned = product.modifierGroupIds.contains(group.id) ||
          group.targetProductIds.contains(product.id);
      final categoryAssigned = (product.useCategoryDefaults && categoryDefaultIds.contains(group.id)) ||
          group.targetCategoryIds.contains(product.categoryId);

      if (directlyAssigned || categoryAssigned) {
        result.add(group);
      }
    }
    return result;
  }

  List<String> defaultModifierGroupIdsForCategory(String categoryId) {
    final explicitFromCategory = categoryById(categoryId)?.modifierGroupIds ?? const <String>[];
    final fromGroups = _modifierGroups
        .where((g) => g.enabled && g.targetCategoryIds.contains(categoryId))
        .map((g) => g.id);
    final combined = <String>{...explicitFromCategory, ...fromGroups};
    if (combined.isNotEmpty) {
      return combined.toList();
    }
    // Backward compatibility with sample catalog if no category assignments are configured
    if (_isDrinkCategory(categoryId)) {
      return const <String>['drink-size', 'milk', 'extras']
          .where((id) => modifierGroupById(id) != null && (modifierGroupById(id)?.enabled ?? false))
          .toList();
    }
    if (_isSnackCategory(categoryId)) {
      return const <String>['snack-size']
          .where((id) => modifierGroupById(id) != null && (modifierGroupById(id)?.enabled ?? false))
          .toList();
    }
    return const <String>[];
  }

  bool _isDrinkCategory(String categoryId) {
    final category = _categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    return const <String>['coffee', 'shakes'].contains(categoryId) ||
        const <String>['☕', '🧊', '🍵', '🥤'].contains(category?.icon);
  }

  bool _isSnackCategory(String categoryId) {
    final category = _categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    return categoryId == 'snacks' ||
        const <String>[
          '🥐',
          '🍞',
          '🍿',
          '🥟',
          '🍗',
          '🍟',
          '🍢',
          '🧀',
        ].contains(category?.icon);
  }

  List<SelectedModifier> resolveDefaultModifiers(Product product) {
    final result = <SelectedModifier>[];
    for (final group in modifierGroupsForProduct(product)) {
      if (group.options.isEmpty) {
        continue;
      }
      final option = group.options.firstWhere(
        (opt) => opt.isDefault,
        orElse: () => group.options.first,
      );
      result.add(
        SelectedModifier(
          groupId: group.id,
          optionId: option.id,
          label: option.name,
          priceDelta: option.priceDelta,
          isDefault: true,
        ),
      );
    }
    return result;
  }

  void addModifierGroup(ModifierGroup group) {
    _modifierGroups = [..._modifierGroups, group];
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void updateModifierGroup(ModifierGroup group) {
    final index = _modifierGroups.indexWhere((g) => g.id == group.id);
    if (index == -1) {
      addModifierGroup(group);
      return;
    }
    _modifierGroups = [
      ..._modifierGroups.sublist(0, index),
      group,
      ..._modifierGroups.sublist(index + 1),
    ];
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void deleteModifierGroup(String groupId) {
    _modifierGroups = _modifierGroups.where((g) => g.id != groupId).toList();
    _products = _products.map((p) {
      if (p.modifierGroupIds.contains(groupId)) {
        return Product(
          id: p.id,
          name: p.name,
          categoryId: p.categoryId,
          price: p.price,
          description: p.description,
          badge: p.badge,
          modifierGroupIds:
              p.modifierGroupIds.where((id) => id != groupId).toList(),
          imageUrl: p.imageUrl,
          isAvailable: p.isAvailable,
          useCategoryDefaults: p.useCategoryDefaults,
        );
      }
      return p;
    }).toList();
    _categories = _categories.map((c) {
      if (c.modifierGroupIds.contains(groupId)) {
        return c.copyWith(
          modifierGroupIds:
              c.modifierGroupIds.where((id) => id != groupId).toList(),
        );
      }
      return c;
    }).toList();
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void toggleModifierGroupEnabled(String groupId, bool enabled) {
    final index = _modifierGroups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      final existing = _modifierGroups[index];
      _modifierGroups = [
        ..._modifierGroups.sublist(0, index),
        existing.copyWith(enabled: enabled),
        ..._modifierGroups.sublist(index + 1),
      ];
      unawaited(_saveCurrentStateSnapshot());
      unawaited(_saveSharedCatalog());
      notifyListeners();
    }
  }

  void reorderModifierGroups(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _modifierGroups.length ||
        newIndex < 0 ||
        newIndex >= _modifierGroups.length ||
        oldIndex == newIndex) {
      return;
    }
    final list = List<ModifierGroup>.from(_modifierGroups);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _modifierGroups = list;
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
  }

  void assignModifierGroup(
    String groupId, {
    List<String>? categoryIds,
    List<String>? productIds,
  }) {
    final index = _modifierGroups.indexWhere((g) => g.id == groupId);
    if (index == -1) return;
    final existing = _modifierGroups[index];
    _modifierGroups = [
      ..._modifierGroups.sublist(0, index),
      existing.copyWith(
        targetCategoryIds: categoryIds ?? existing.targetCategoryIds,
        targetProductIds: productIds ?? existing.targetProductIds,
      ),
      ..._modifierGroups.sublist(index + 1),
    ];
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_saveSharedCatalog());
    notifyListeners();
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
    final existing = _products[index];
    _products[index] = Product(
      imageUrl: existing.imageUrl,
      isAvailable: existing.isAvailable,
      useCategoryDefaults: existing.useCategoryDefaults,
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

  void replaceProducts(
    List<Product> products, {
    List<Category>? categories,
    List<ModifierGroup>? modifierGroups,
  }) {
    final selectedId = selectedCategory?.id;
    if (categories != null) _categories = List.of(categories);
    if (modifierGroups != null) _modifierGroups = List.of(modifierGroups);
    final productById = <String, Product>{
      for (final product in products) product.id: product,
    };
    _products = List<Product>.from(products);
    final updatedCart = <CartItem>[];
    for (final item in _cart) {
      final product = productById[item.product.id];
      if (product == null || !product.isAvailable) {
        continue;
      }
      final groups = modifierGroupsForProduct(product);
      final refreshedModifiers = <SelectedModifier>[];
      for (final modifier in item.selectedModifiers) {
        for (final group in groups.where(
          (group) => group.id == modifier.groupId,
        )) {
          for (final option in group.options.where(
            (option) => option.id == modifier.optionId,
          )) {
            refreshedModifiers.add(
              SelectedModifier(
                groupId: group.id,
                optionId: option.id,
                label: option.name,
                priceDelta: option.priceDelta,
                isDefault: option.isDefault,
              ),
            );
          }
        }
      }
      final valid = groups.every((group) {
        final count = refreshedModifiers
            .where((modifier) => modifier.groupId == group.id)
            .length;
        return count >= group.minSelected &&
            (group.maxSelected == 0 || count <= group.maxSelected);
      });
      if (valid) {
        updatedCart.add(
          item.copyWith(
            product: product,
            selectedModifiers: refreshedModifiers,
          ),
        );
      }
    }
    _cart
      ..clear()
      ..addAll(updatedCart);
    if (_activeProductId != null &&
        !productById.containsKey(_activeProductId)) {
      _activeProductId = null;
    }
    final visibleCategories = cashierCategories;
    final matchingIndex = visibleCategories.indexWhere(
      (category) => category.id == selectedId,
    );
    _selectedCategoryIndex = matchingIndex < 0
        ? _selectedCategoryIndex.clamp(
            0,
            visibleCategories.isEmpty ? 0 : visibleCategories.length - 1,
          )
        : matchingIndex;
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
    if (quantity <= 0 || !product.isAvailable || _isCheckingOut) {
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
    _selectedDiscountId = null;
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
    _selectedDiscountId = null;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _orderType = order.orderType.isEmpty ? 'Dine-in' : order.orderType;
    _activeOrders = _activeOrders
        .where((item) => item.id != order.id)
        .toList(growable: false);
    unawaited(_saveCurrentStateSnapshot());
    unawaited(_removeSharedActiveOrder(order.id));
    notifyListeners();
  }

  final Set<String> _changingOrderIds = {};

  OrderRecord? transactionForQueue(OrderQueueRecord queue) {
    final id = OrderLifecycle.transactionId(queue.id);
    for (final order in _recentOrders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<bool> updateDeliveryStatus(
    OrderQueueRecord order,
    OrderQueueStatus newStatus,
  ) async {
    final queueIndex = _activeOrders.indexWhere((item) => item.id == order.id);
    if (queueIndex < 0) return false;

    final updatedOrder = _activeOrders[queueIndex].copyWith(status: newStatus);

    if (newStatus == OrderQueueStatus.delivered) {
      _activeOrders.removeAt(queueIndex);
      final txId = OrderLifecycle.transactionId(order.id);
      final existsInRecent = _recentOrders.any((r) => r.id == txId);
      if (!existsInRecent) {
        final paymentType =
            (order.paymentMethod?.toLowerCase().contains('gcash') ?? false)
                ? PaymentType.eWallet
                : PaymentType.cash;
        final record = OrderRecord(
          id: txId,
          sequence: order.sequence,
          orderNumber: order.displayOrderNumber,
          status: OrderStatus.paid,
          orderType: order.orderType,
          paymentType: paymentType,
          cashierName: _cashierName,
          createdAt: order.createdAt,
          subtotal: order.subtotal,
          discount: 0,
          tax: 0,
          serviceCharge: 0,
          total: order.total,
          cashReceived: order.total,
          change: 0,
          items: order.items,
          vatEnabled: false,
        );
        _recentOrders = [record, ..._recentOrders];
        _todaySales += order.total;
      }
    } else {
      _activeOrders[queueIndex] = updatedOrder;
    }

    notifyListeners();
    unawaited(_saveCurrentStateSnapshot());

    if (Firebase.apps.isNotEmpty && _currentUserId != null) {
      if (newStatus == OrderQueueStatus.delivered) {
        await _removeSharedActiveOrder(order.id);
        await _saveSharedOrders();
      } else {
        await _saveSharedOrders();
      }

      final orderNumber = order.displayOrderNumber;
      if (orderNumber.isNotEmpty) {
        final String lunanStatusStr = switch (newStatus) {
          OrderQueueStatus.preparing => 'preparing',
          OrderQueueStatus.onTheWay => 'onTheWay',
          OrderQueueStatus.delivered => 'delivered',
          OrderQueueStatus.pending => 'received',
          _ => newStatus.name,
        };

        final updatePayload = {
          'status': lunanStatusStr,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        try {
          // 1. Update under orderNumber (e.g. LN-20261030-001)
          await _customerOrdersReference.child(orderNumber).update(updatePayload);

          // 2. Also update under trackingToken (e.g. trk_nlkqmtuanpkx9od92f0x2oio756ahrgx)
          String? tokenToUpdate = order.trackingToken;
          if (tokenToUpdate == null || tokenToUpdate.isEmpty) {
            final snap = await _customerOrdersReference
                .child(orderNumber)
                .child('trackingToken')
                .get()
                .timeout(const Duration(seconds: 2));
            if (snap.exists && snap.value != null) {
              tokenToUpdate = snap.value.toString();
            }
          }
          if (tokenToUpdate != null &&
              tokenToUpdate.isNotEmpty &&
              tokenToUpdate != orderNumber) {
            await _customerOrdersReference
                .child(tokenToUpdate)
                .update(updatePayload);
          }
        } catch (e) {
          debugPrint('[CoffeePosController] Error syncing customer_orders: $e');
        }
      }
    }

    return true;
  }

  Future<bool> completeOrder(OrderQueueRecord order) => changeOrderStatus(
    order,
    action: OrderAction.complete,
    reason: 'Order completed',
  );

  Future<bool> changeOrderStatus(
    OrderQueueRecord order, {
    required OrderAction action,
    required String reason,
    double? expectedRefundAmount,
  }) async {
    if (!_changingOrderIds.add(order.id)) return false;
    try {
      final at = DateTime.now();
      Map<String, dynamic> transition(Map<String, dynamic> state) =>
          OrderLifecycle.apply(
            state,
            queueId: order.id,
            action: action,
            reason: reason,
            userId: _currentUserId ?? 'local',
            cashierName: _cashierName,
            at: at,
            expectedRefundAmount: expectedRefundAmount,
          );
      // Check locally before opening a database transaction. The transaction
      // repeats these checks against current shared state to reject stale taps.
      var updated = transition(_sharedOrdersJson());
      if (Firebase.apps.isNotEmpty && _currentUserId != null) {
        await _sharedOrdersReference.get();
        String? failure;
        final result = await _sharedOrdersReference.runTransaction((value) {
          if (value is! Map) return Transaction.abort();
          try {
            final next = transition(Map<String, dynamic>.from(value));
            next['updatedAt'] = ServerValue.timestamp;
            return Transaction.success(next);
          } on StateError catch (error) {
            failure = error.message;
            return Transaction.abort();
          }
        }, applyLocally: false);
        if (!result.committed || result.snapshot.value is! Map) {
          throw StateError(
            failure ??
                'Order status could not be saved. Refresh and try again.',
          );
        }
        updated = Map<String, dynamic>.from(result.snapshot.value as Map);
      } else {
        // Offline/local mode must persist successfully before reporting success.
        await flushPersistence();
        final prefs = await SharedPreferences.getInstance();
        final snapshot =
            jsonDecode(exportStateJson(pretty: false)) as Map<String, dynamic>;
        snapshot.addAll({
          'activeOrders': updated['activeOrders'],
          'recentOrders': updated['recentOrders'],
          'todaySales': updated['todaySales'],
        });
        if (!await prefs.setString(
          _scopedPreferenceKey(_resetSnapshotPreferenceKey),
          jsonEncode(snapshot),
        )) {
          throw StateError('Order status could not be saved. Try again.');
        }
      }
      _applySharedOrders(updated);
      notifyListeners();
      await _saveCurrentStateSnapshot();
      return true;
    } finally {
      _changingOrderIds.remove(order.id);
    }
  }

  void updateDiscountSettings({
    required bool enabled,
    required List<DiscountOption> options,
  }) {
    final ids = <String>{};
    final names = <String>{};
    for (final option in options) {
      if (option.id.isEmpty ||
          !ids.add(option.id) ||
          option.name.trim().isEmpty ||
          !names.add(option.name.trim().toLowerCase()) ||
          option.type == DiscountType.none ||
          !option.value.isFinite ||
          option.value < 0 ||
          (option.type == DiscountType.percentage && option.value > 100) ||
          (!option.isStatutory && option.enabled && option.value == 0)) {
        throw ArgumentError(
          'Use unique discount names and valid positive amounts (percentages up to 100).',
        );
      }
    }
    _discountsEnabled = enabled;
    _discountOptions = List.of(options);
    _selectedDiscountId = selectedDiscountId;
    if (!enabled) _discountAmount = 0;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void selectDiscount(String? id) {
    if (_isCheckingOut) return;
    if (id != null && !availableDiscounts.any((option) => option.id == id)) {
      return;
    }
    _selectedDiscountId = id;
    _discountAmount = 0;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateDiscount(double value) {
    _selectedDiscountId = null;
    _discountAmount = value.clamp(0, double.infinity);
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateVatEnabled(bool value) {
    _vatEnabled = value;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  void updateTaxSettings({
    bool? vatEnabled,
    double? taxRate,
    double? serviceChargeRate,
  }) {
    if (vatEnabled != null) {
      _vatEnabled = vatEnabled;
    }
    if (taxRate != null) {
      _taxRate = taxRate.clamp(0, 1);
    }
    if (serviceChargeRate != null) {
      _serviceChargeRate = serviceChargeRate.clamp(0, 1);
    }
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
    String? thermalTransport,
    int? thermalPaperWidth,
    int? thermalFeedLines,
    bool? thermalAutoCut,
    bool? thermalOpenCashDrawer,
    bool? thermalWebKiosk,
  }) {
    _printerName = printerName.trim().isEmpty
        ? _printerName
        : printerName.trim();
    _printerUrl = printerUrl.trim();
    _autoPrintReceipts = autoPrintReceipts;
    _thermalTransport = thermalTransport ?? _thermalTransport;
    _thermalPaperWidth = switch (thermalPaperWidth) {
      0 || 50 || 58 || 80 => thermalPaperWidth!,
      _ => _thermalPaperWidth,
    };
    _thermalFeedLines = (thermalFeedLines ?? _thermalFeedLines)
        .clamp(0, 8)
        .toInt();
    _thermalAutoCut = thermalAutoCut ?? _thermalAutoCut;
    _thermalOpenCashDrawer = thermalOpenCashDrawer ?? _thermalOpenCashDrawer;
    _thermalWebKiosk = thermalWebKiosk ?? _thermalWebKiosk;
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  /// Returns the effective paper width, resolving 0 (AUTO) using printer hints or safe 80mm fallback.
  int get effectiveThermalPaperWidth {
    if (_thermalPaperWidth == 58 ||
        _thermalPaperWidth == 80 ||
        _thermalPaperWidth == 50) {
      return _thermalPaperWidth;
    }
    final lower = _printerName.toLowerCase();
    if (lower.contains('58') ||
        lower.contains('2inch') ||
        lower.contains('58mm')) {
      return 58;
    }
    return 80;
  }

  /// Automatically discovers connected printers, picks the best thermal/default printer,
  /// and configures roll width, Direct Print (no prompt), and auto-print enabled.
  /// Preserves intentional manual 58mm or 80mm roll selection unless [force] is true.
  Future<bool> autoConfigurePrinter({bool force = false}) async {
    try {
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) return false;
      final detected = PrinterResolver.autoDetectPrinter(printers);
      if (detected != null) {
        _printerName = detected.name;
        _printerUrl = detected.url;
        _thermalTransport = 'Direct print (no prompt)';
        if (force || _thermalPaperWidth == 0) {
          final lower = detected.name.toLowerCase();
          if (lower.contains('58') ||
              lower.contains('2inch') ||
              lower.contains('58mm')) {
            _thermalPaperWidth = 58;
          } else {
            _thermalPaperWidth = 80;
          }
        }
        _autoPrintReceipts = true;
        unawaited(_saveCurrentStateSnapshot());
        notifyListeners();
        return true;
      }
    } catch (_) {
      // In test/mock environments or platforms without printing support, ignore safely.
    }
    return false;
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
    if (isDemo) {
      await resetDemoData();
      return;
    }
    final bootstrap = await repository.loadBootstrap();
    _applyBootstrap(bootstrap);
    _selectedCategoryIndex = 0;
    _activeProductId = null;
    _cart.clear();
    _discountAmount = 0;
    _selectedDiscountId = null;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _cashierName = 'Alex';
    _selectedCustomerId = null;
    _storeName = 'LUNAN';
    _storeAddress = 'Store address not set';
    _storeContact = 'Store contact not set';
    _receiptHeader = 'May lugar ka rito.';
    _receiptFooter = 'Visit us again soon.';
    _currencyCode = 'PHP';
    _currencySymbol = '₱';
    _printerName = 'GEZHI_micro_printer';
    _autoPrintReceipts = true;
    _thermalTransport = 'Direct print (no prompt)';
    _thermalPaperWidth = 80;
    _compactReceiptStyle = false;
    _showBadges = true;
    _highContrastMode = false;
    await _clearSavedStateSnapshot();
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    final demoBootstrap = StoreBootstrap.demo();
    _applyBootstrap(demoBootstrap);
    _selectedCategoryIndex = 0;
    _activeProductId = null;
    _cart.clear();
    _discountAmount = 0;
    _selectedDiscountId = null;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _cashierName = 'Alex';
    _selectedCustomerId = null;
    _storeName = 'LUNAN';
    _storeAddress = 'Store address not set';
    _storeContact = 'Store contact not set';
    _receiptHeader = 'May lugar ka rito.';
    _receiptFooter = 'Visit us again soon.';
    _currencyCode = 'PHP';
    _currencySymbol = '₱';
    _printerName = 'GEZHI_micro_printer';
    _autoPrintReceipts = true;
    _thermalTransport = 'Direct print (no prompt)';
    _thermalPaperWidth = 80;
    _compactReceiptStyle = false;
    _showBadges = true;
    _highContrastMode = false;
    await _clearSavedStateSnapshot();
    await _saveLocalStateSnapshot(exportStateJson(pretty: false));
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
    _selectedDiscountId = null;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _cashierName = 'Alex';
    _selectedCustomerId = null;
    _storeName = 'LUNAN';
    _storeAddress = 'Store address not set';
    _storeContact = 'Store contact not set';
    _receiptHeader = 'May lugar ka rito.';
    _receiptFooter = 'Visit us again soon.';
    _currencyCode = 'PHP';
    _currencySymbol = '₱';
    _printerName = 'GEZHI_micro_printer';
    _autoPrintReceipts = true;
    _thermalTransport = 'Direct print (no prompt)';
    _thermalPaperWidth = 80;
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
    _selectedDiscountId = null;
    _taxRate = 0.12;
    _serviceChargeRate = 0.0;
    _cashReceived = 0;
    _paymentType = PaymentType.card;
    _cashierName = 'Alex';
    _selectedCustomerId = null;
    _storeName = 'LUNAN';
    _storeAddress = 'Store address not set';
    _storeContact = 'Store contact not set';
    _receiptHeader = 'May lugar ka rito.';
    _receiptFooter = 'Visit us again soon.';
    _currencyCode = 'PHP';
    _currencySymbol = '₱';
    _printerName = 'GEZHI_micro_printer';
    _autoPrintReceipts = true;
    _thermalTransport = 'Direct print (no prompt)';
    _thermalPaperWidth = 80;
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
      if (isDemo) {
        return null;
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
    if (!isDemo) {
      await _saveFirebaseStateSnapshot(snapshot);
    }
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
    if (isDemo || Firebase.apps.isEmpty || _currentUserId == null) {
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

  Future<Map<String, dynamic>?> _loadSharedOrders() async {
    if (isDemo || Firebase.apps.isEmpty || _currentUserId == null) {
      return null;
    }
    try {
      final event = await _sharedOrdersReference.once().timeout(
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
    if (isDemo || Firebase.apps.isEmpty || _currentUserId == null) {
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

  void _startSharedOrdersSubscription() {
    _sharedOrdersSubscription?.cancel();
    if (isDemo || Firebase.apps.isEmpty || _currentUserId == null) {
      return;
    }
    _sharedOrdersSubscription = _sharedOrdersReference.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return;
      }
      _applySharedOrders(Map<String, dynamic>.from(value));
      unawaited(_saveLocalStateSnapshot(exportStateJson(pretty: false)));
      notifyListeners();
    });
  }

  Future<void> _saveSharedCatalog() async {
    if (isDemo ||
        Firebase.apps.isEmpty ||
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

  Future<bool> _saveSharedOrders() async {
    if (isDemo || Firebase.apps.isEmpty || _currentUserId == null) {
      return false;
    }
    try {
      final incoming = _sharedOrdersJson();
      final result = await _sharedOrdersReference
          .runTransaction((value) {
            if (value is! Map) return Transaction.success(incoming);
            return Transaction.success(
              OrderLifecycle.merge(Map<String, dynamic>.from(value), incoming),
            );
          }, applyLocally: false)
          .timeout(const Duration(seconds: 3));
      return result.committed;
    } catch (_) {
      // The user's local snapshot remains available if sync fails.
      return false;
    }
  }

  Future<bool> _removeSharedActiveOrder(String orderId) async {
    if (isDemo || Firebase.apps.isEmpty || _currentUserId == null) {
      return false;
    }
    try {
      final result = await _sharedOrdersReference
          .child('activeOrders')
          .runTransaction((value) {
            final current = switch (value) {
              List<Object?> values => values,
              Map<Object?, Object?> values => values.values.toList(),
              _ => const <Object?>[],
            };
            final remainingOrders = current
                .where((value) {
                  if (value is! Map) {
                    return true;
                  }
                  return value['id'] != orderId;
                })
                .toList(growable: false);
            return Transaction.success(remainingOrders);
          })
          .timeout(const Duration(seconds: 5));
      return result.committed;
    } catch (_) {
      return false;
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
      if (!isDemo) {
        await prefs
            .remove(_resetSnapshotPreferenceKey)
            .timeout(const Duration(seconds: 2));
        await prefs
            .remove(_scopedPreferenceKey(_legacyResetFlagPreferenceKey))
            .timeout(const Duration(seconds: 2));
        await prefs
            .remove(_legacyResetFlagPreferenceKey)
            .timeout(const Duration(seconds: 2));
      }
    } catch (_) {
      // Ignore cleanup failures.
    }
    if (!isDemo) {
      unawaited(_clearFirebaseStateSnapshot());
    }
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

  int _computeNextSequence({DateTime? forDate}) {
    final now = forDate ?? DateTime.now();
    var maxSeq = 0;
    for (final o in _recentOrders) {
      if (o.createdAt.year == now.year &&
          o.createdAt.month == now.month &&
          o.createdAt.day == now.day) {
        if (o.sequence > maxSeq) maxSeq = o.sequence;
      }
    }
    for (final q in _activeOrders) {
      if (q.createdAt.year == now.year &&
          q.createdAt.month == now.month &&
          q.createdAt.day == now.day) {
        if (q.sequence > maxSeq) maxSeq = q.sequence;
      }
    }
    return maxSeq + 1;
  }

  Future<OrderRecord?> checkout() async {
    if (!canCheckout) {
      return null;
    }
    _isCheckingOut = true;
    notifyListeners();

    try {
      final nextSequence = _computeNextSequence();
      final draft = OrderDraft(
        cashierName: _cashierName,
        orderType: _orderType,
        paymentType: _paymentType,
        discountAmount: _discountAmount,
        discountApplication: discountApplication,
        taxRate: _taxRate,
        serviceChargeRate: _serviceChargeRate,
        cashReceived: _cashReceived,
        vatEnabled: _vatEnabled,
        lines: _cart
            .map(
              (item) {
                final category = categoryById(item.product.categoryId);
                return CartLineInput(
                  lineId: item.lineId ?? item.product.id,
                  productId: item.product.id,
                  quantity: item.quantity,
                  modifierIds: item.selectedModifiers
                      .map((modifier) => modifier.optionId)
                      .toList(growable: false),
                  productName: item.product.name,
                  categoryId: item.product.categoryId,
                  categoryName: category?.name,
                  unitPrice: item.singleItemPrice,
                  modifierLabels: item.selectedModifiers
                      .map((modifier) => modifier.label)
                      .toList(growable: false),
                  lineTotal: item.lineTotal,
                  selectedModifiers: item.selectedModifiers,
                );
              },
            )
            .toList(growable: false),
        note: 'Prototype checkout',
        shiftId: _shiftId,
      );

      final order = await repository.createOrder(draft, sequence: nextSequence);
      _recentOrders = [order, ..._recentOrders];
      _activeOrders = [
        OrderQueueRecord(
          id: 'Q-${order.id}',
          sequence: order.sequence,
          orderNumber: order.orderNumber,
          status: OrderQueueStatus.preparing,
          customerName: selectedCustomer?.name ?? 'Walk-in',
          orderType: _orderType,
          createdAt: order.createdAt,
          items: order.items,
        ),
        ..._activeOrders,
      ];
      _todaySales += order.total;
      _resetProductsForNextOrder();
      clearCart(persist: false);
      await _saveCurrentStateSnapshot();
      await _saveSharedOrders();
      return order;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }

  /// Prints the paid order as one customer + kitchen package on the primary printer.
  Future<receipt_printer.PrintResult> printOrderPackage(
    OrderRecord order, {
    bool manualReprint = false,
    String? transportOverride,
  }) => printReceipt(
    order,
    manualReprint: manualReprint,
    transportOverride: transportOverride,
    includeKitchen: true,
  );

  Future<receipt_printer.PrintResult> printReceipt(
    OrderRecord order, {
    bool manualReprint = false,
    String? transportOverride,
    bool includeKitchen = false,
  }) {
    return receipt_printer.printReceipt(
      order: order,
      includeKitchen: includeKitchen,
      storeName: _storeName,
      storeAddress: _storeAddress,
      storeContact: _storeContact,
      receiptHeader: _receiptHeader,
      receiptFooter: _receiptFooter,
      printerName: _printerName,
      printerUrl: _printerUrl,
      compactReceiptStyle: _compactReceiptStyle,
      thermalTransport: transportOverride ?? _thermalTransport,
      thermalPaperWidth: effectiveThermalPaperWidth,
      feedLines: _thermalFeedLines,
      autoCut: _thermalAutoCut,
      openCashDrawer: _thermalOpenCashDrawer,
      manualReprint: manualReprint,
      webKioskPrinting: _thermalWebKiosk,
    );
  }

  void updateKitchenPrinterSettings({
    required String printerName,
    required String printerUrl,
  }) {
    _kitchenPrinterName = printerName.trim();
    _kitchenPrinterUrl = printerUrl.trim();
    unawaited(_saveCurrentStateSnapshot());
    notifyListeners();
  }

  Future<receipt_printer.PrintResult> printPreparationTicket(
    OrderQueueRecord queue, {
    String note = '',
    String? transportOverride,
  }) {
    final effectivePrinterName = _kitchenPrinterName.isNotEmpty
        ? _kitchenPrinterName
        : _printerName;
    final effectivePrinterUrl = _kitchenPrinterUrl.isNotEmpty
        ? _kitchenPrinterUrl
        : _printerUrl;
    final ticket = receipt_printer.PreparationTicketData.fromQueueRecord(
      queue,
      note: note,
      printerName: effectivePrinterName,
    );
    return receipt_printer.printPreparationTicket(
      ticket: ticket,
      printerName: effectivePrinterName,
      printerUrl: effectivePrinterUrl,
      compactReceiptStyle: _compactReceiptStyle,
      thermalTransport: transportOverride ?? _thermalTransport,
      thermalPaperWidth: effectiveThermalPaperWidth,
      feedLines: _thermalFeedLines,
      autoCut: _thermalAutoCut,
      webKioskPrinting: _thermalWebKiosk,
    );
  }

  Future<receipt_printer.PrintResult> printPreparationTicketFromOrder(
    OrderRecord order, {
    String note = '',
    String? transportOverride,
  }) {
    final effectivePrinterName = _kitchenPrinterName.isNotEmpty
        ? _kitchenPrinterName
        : _printerName;
    final effectivePrinterUrl = _kitchenPrinterUrl.isNotEmpty
        ? _kitchenPrinterUrl
        : _printerUrl;
    final ticket = receipt_printer.PreparationTicketData.fromOrderRecord(
      order,
      note: note,
      printerName: effectivePrinterName,
    );
    return receipt_printer.printPreparationTicket(
      ticket: ticket,
      printerName: effectivePrinterName,
      printerUrl: effectivePrinterUrl,
      compactReceiptStyle: _compactReceiptStyle,
      thermalTransport: transportOverride ?? _thermalTransport,
      thermalPaperWidth: effectiveThermalPaperWidth,
      feedLines: _thermalFeedLines,
      autoCut: _thermalAutoCut,
      webKioskPrinting: _thermalWebKiosk,
    );
  }

  Future<bool> isPrinterAvailable() {
    final config = receipt_printer.PrinterConfig(
      paperWidth: receipt_printer.PaperWidth.fromInt(
        effectiveThermalPaperWidth,
      ),
      transport: receipt_printer.ThermalTransport.fromString(_thermalTransport),
      printerName: _printerName,
      printerUrl: _printerUrl,
      feedLines: _thermalFeedLines,
      autoCut: _thermalAutoCut,
      openCashDrawer: _thermalOpenCashDrawer,
      compactReceiptStyle: _compactReceiptStyle,
      webKioskPrinting: _thermalWebKiosk,
    );
    return receipt_printer.ThermalPrinterService.instance.isPrinterAvailable(
      config,
    );
  }

  @override
  void dispose() {
    _realtimeSnapshotSubscription?.cancel();
    _sharedCatalogSubscription?.cancel();
    _sharedOrdersSubscription?.cancel();
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
