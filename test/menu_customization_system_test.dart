import 'dart:convert';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/data/menu_workbook.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/admin_dashboard.dart';
import 'package:cafe_and_brews/src/ui/widgets/cashier_dashboard.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CoffeePosController createController() {
    final repository = InMemoryCoffeePosRepository();
    final controller = CoffeePosController(repository: repository);
    final bootstrap = StoreBootstrap(
      categories: [
        const Category(id: 'cat-drinks', name: 'Drinks', icon: 'coffee'),
        const Category(id: 'cat-rice-bowls', name: 'Rice Bowls', icon: 'lunch_dining'),
      ],
      products: [
        const Product(
          id: 'prod-latte',
          name: 'Iced Latte',
          categoryId: 'cat-drinks',
          price: 150.0,
          description: 'Espresso with milk',
          badge: '',
          modifierGroupIds: [],
        ),
        const Product(
          id: 'prod-bowl',
          name: 'Beef Gyudon',
          categoryId: 'cat-rice-bowls',
          price: 280.0,
          description: 'Japanese beef rice bowl',
          badge: 'Popular',
          modifierGroupIds: [],
        ),
      ],
      modifierGroups: [
        const ModifierGroup(
          id: 'group-size',
          name: 'Size',
          minSelected: 1,
          maxSelected: 1,
          enabled: true,
          targetCategoryIds: ['cat-drinks'],
          options: [
            ModifierOption(id: 'opt-reg', name: 'Regular', priceDelta: 0.0, isDefault: true),
            ModifierOption(id: 'opt-large', name: 'Large', priceDelta: 30.0, isDefault: false),
          ],
        ),
        const ModifierGroup(
          id: 'group-milk',
          name: 'Milk Alternative',
          minSelected: 0,
          maxSelected: 1,
          enabled: true,
          targetCategoryIds: ['cat-drinks'],
          options: [
            ModifierOption(id: 'opt-oat', name: 'Oat Milk', priceDelta: 40.0, isDefault: false),
            ModifierOption(id: 'opt-almond', name: 'Almond Milk', priceDelta: 40.0, isDefault: false),
          ],
        ),
        const ModifierGroup(
          id: 'group-rice',
          name: 'Rice Type',
          minSelected: 1,
          maxSelected: 1,
          enabled: true,
          targetCategoryIds: ['cat-rice-bowls'],
          options: [
            ModifierOption(id: 'opt-white', name: 'White Rice', priceDelta: 0.0, isDefault: true),
            ModifierOption(id: 'opt-garlic', name: 'Garlic Rice', priceDelta: 20.0, isDefault: false),
          ],
        ),
        const ModifierGroup(
          id: 'group-toppings',
          name: 'Extra Toppings',
          minSelected: 0,
          maxSelected: 3,
          enabled: true,
          targetCategoryIds: ['cat-rice-bowls'],
          options: [
            ModifierOption(id: 'opt-egg', name: 'Onsen Egg', priceDelta: 25.0, isDefault: false),
            ModifierOption(id: 'opt-kimchi', name: 'Kimchi', priceDelta: 35.0, isDefault: false),
          ],
        ),
      ],
      inventoryHealth: const [],
      todaySales: 0.0,
      recentOrders: const [],
      activeShifts: const [],
      activeOrders: const [],
      customers: const [],
    );
    controller.importStateJson(jsonEncode(bootstrap.toJson()));
    return controller;
  }

  group('Dynamic ModifierGroup Domain Model Tests', () {
    test('selectionRuleLabel computes correctly for all single and multi combinations', () {
      const singleRequired = ModifierGroup(
        id: '1',
        name: 'Size',
        minSelected: 1,
        maxSelected: 1,
        options: [],
      );
      expect(singleRequired.isSingleSelect, isTrue);
      expect(singleRequired.isRequired, isTrue);
      expect(singleRequired.selectionRuleLabel, 'Single-select (Required)');

      const singleOptional = ModifierGroup(
        id: '2',
        name: 'Flavor',
        minSelected: 0,
        maxSelected: 1,
        options: [],
      );
      expect(singleOptional.isSingleSelect, isTrue);
      expect(singleOptional.isRequired, isFalse);
      expect(singleOptional.selectionRuleLabel, 'Single-select (Optional)');

      const multiRequiredExact = ModifierGroup(
        id: '3',
        name: 'Sides',
        minSelected: 2,
        maxSelected: 2,
        options: [],
      );
      expect(multiRequiredExact.isSingleSelect, isFalse);
      expect(multiRequiredExact.isRequired, isTrue);
      expect(multiRequiredExact.selectionRuleLabel, 'Multi-select (Required 2)');

      const multiRequiredRange = ModifierGroup(
        id: '4',
        name: 'Toppings',
        minSelected: 1,
        maxSelected: 3,
        options: [],
      );
      expect(multiRequiredRange.isRequired, isTrue);
      expect(multiRequiredRange.selectionRuleLabel, 'Multi-select (Required 1–3)');

      const multiOptionalLimit = ModifierGroup(
        id: '5',
        name: 'Add-ons',
        minSelected: 0,
        maxSelected: 4,
        options: [],
      );
      expect(multiOptionalLimit.isRequired, isFalse);
      expect(multiOptionalLimit.selectionRuleLabel, 'Multi-select (Optional up to 4)');

      const multiOptionalUnlimited = ModifierGroup(
        id: '6',
        name: 'Extra Sauces',
        minSelected: 0,
        maxSelected: 0,
        options: [],
      );
      expect(multiOptionalUnlimited.isRequired, isFalse);
      expect(multiOptionalUnlimited.selectionRuleLabel, 'Multi-select (Optional)');
    });

    test('JSON serialization round-trip preserves all dynamic properties', () {
      const group = ModifierGroup(
        id: 'test-group',
        name: 'Temperature',
        minSelected: 1,
        maxSelected: 1,
        enabled: false,
        targetCategoryIds: ['cat-coffee'],
        targetProductIds: ['prod-espresso'],
        options: [
          ModifierOption(id: 'hot', name: 'Hot', priceDelta: 0.0, isDefault: true),
          ModifierOption(id: 'iced', name: 'Iced', priceDelta: 10.0, isDefault: false),
        ],
      );

      final json = group.toJson();
      final restored = ModifierGroup.fromJson(json);

      expect(restored.id, 'test-group');
      expect(restored.name, 'Temperature');
      expect(restored.minSelected, 1);
      expect(restored.maxSelected, 1);
      expect(restored.enabled, isFalse);
      expect(restored.targetCategoryIds, ['cat-coffee']);
      expect(restored.targetProductIds, ['prod-espresso']);
      expect(restored.options.length, 2);
      expect(restored.options[1].priceDelta, 10.0);
    });
  });

  group('CoffeePosController Customization Logic Tests', () {
    test('modifierGroupsForProduct resolves dynamic groups based on product category', () {
      final controller = createController();
      addTearDown(controller.dispose);

      final latte = controller.productById('prod-latte')!;
      final latteGroups = controller.modifierGroupsForProduct(latte);

      expect(latteGroups.map((g) => g.id), containsAll(['group-size', 'group-milk']));
      expect(latteGroups.map((g) => g.id), isNot(contains('group-rice')));
      expect(latteGroups.map((g) => g.id), isNot(contains('group-toppings')));

      final bowl = controller.productById('prod-bowl')!;
      final bowlGroups = controller.modifierGroupsForProduct(bowl);

      expect(bowlGroups.map((g) => g.id), containsAll(['group-rice', 'group-toppings']));
      expect(bowlGroups.map((g) => g.id), isNot(contains('group-size')));
      expect(bowlGroups.map((g) => g.id), isNot(contains('group-milk')));
    });

    test('toggling group enabled disables it from product customization', () {
      final controller = createController();
      addTearDown(controller.dispose);

      final latte = controller.productById('prod-latte')!;
      expect(controller.modifierGroupsForProduct(latte).any((g) => g.id == 'group-milk'), isTrue);

      controller.toggleModifierGroupEnabled('group-milk', false);
      expect(controller.modifierGroupsForProduct(latte).any((g) => g.id == 'group-milk'), isFalse);

      controller.toggleModifierGroupEnabled('group-milk', true);
      expect(controller.modifierGroupsForProduct(latte).any((g) => g.id == 'group-milk'), isTrue);
    });

    test('addModifierGroup, updateModifierGroup, and deleteModifierGroup work with cascading cleanup', () {
      final controller = createController();
      addTearDown(controller.dispose);

      const customGroup = ModifierGroup(
        id: 'group-sweetness',
        name: 'Sweetness Level',
        minSelected: 1,
        maxSelected: 1,
        enabled: true,
        targetProductIds: ['prod-latte'],
        options: [
          ModifierOption(id: 'sw-100', name: '100% Sugar', priceDelta: 0.0, isDefault: true),
          ModifierOption(id: 'sw-50', name: '50% Sugar', priceDelta: 0.0, isDefault: false),
          ModifierOption(id: 'sw-0', name: '0% Sugar', priceDelta: 0.0, isDefault: false),
        ],
      );

      controller.addModifierGroup(customGroup);
      final latte = controller.productById('prod-latte')!;
      expect(controller.modifierGroupsForProduct(latte).any((g) => g.id == 'group-sweetness'), isTrue);

      // Update group
      final updated = customGroup.copyWith(name: 'Sugar Level');
      controller.updateModifierGroup(updated);
      expect(controller.modifierGroups.firstWhere((g) => g.id == 'group-sweetness').name, 'Sugar Level');

      // Delete group
      controller.deleteModifierGroup('group-sweetness');
      expect(controller.modifierGroups.any((g) => g.id == 'group-sweetness'), isFalse);
      expect(controller.modifierGroupsForProduct(latte).any((g) => g.id == 'group-sweetness'), isFalse);
    });

    test('reorderModifierGroups correctly reorders groups in the controller', () {
      final controller = createController();
      addTearDown(controller.dispose);

      final initialFirst = controller.modifierGroups.first.id;
      final initialSecond = controller.modifierGroups[1].id;

      controller.reorderModifierGroups(0, 1);

      expect(controller.modifierGroups.first.id, initialSecond);
      expect(controller.modifierGroups[1].id, initialFirst);
    });
  });

  group('Excel Customization Import Engine Tests', () {
    test('parseMenuWorkbook parses dynamic modifier groups with categories and options', () {
      final excel = xl.Excel.createExcel();
      final productsSheet = excel['Products'];
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      excel.setDefaultSheet('Products');

      productsSheet.appendRow([
        xl.TextCellValue('Product ID'),
        xl.TextCellValue('Name'),
        xl.TextCellValue('Category ID'),
        xl.TextCellValue('Category Name'),
        xl.TextCellValue('Category Icon'),
        xl.TextCellValue('Price'),
        xl.TextCellValue('Description'),
        xl.TextCellValue('Badge'),
        xl.TextCellValue('Modifier Group IDs'),
      ]);

      productsSheet.appendRow([
        xl.TextCellValue('dish-1'),
        xl.TextCellValue('Pork Sisig'),
        xl.TextCellValue('cat-mains'),
        xl.TextCellValue('Main Dishes'),
        xl.TextCellValue('restaurant'),
        xl.DoubleCellValue(220.0),
        xl.TextCellValue('Sizzling pork sisig'),
        xl.TextCellValue('Chef Special'),
        xl.TextCellValue('mod-spice, mod-egg'),
      ]);

      final modSheet = excel['Modifiers'];
      modSheet.appendRow([
        xl.TextCellValue('Group ID'),
        xl.TextCellValue('Group Name'),
        xl.TextCellValue('Option ID'),
        xl.TextCellValue('Option Name'),
        xl.TextCellValue('Price Delta'),
        xl.TextCellValue('Min Selected'),
        xl.TextCellValue('Max Selected'),
        xl.TextCellValue('Default'),
        xl.TextCellValue('Active'),
        xl.TextCellValue('Target Categories'),
        xl.TextCellValue('Target Products'),
      ]);

      modSheet.appendRow([
        xl.TextCellValue('mod-spice'),
        xl.TextCellValue('Spice Level'),
        xl.TextCellValue('mild'),
        xl.TextCellValue('Mild'),
        xl.DoubleCellValue(0.0),
        xl.IntCellValue(1),
        xl.IntCellValue(1),
        xl.BoolCellValue(true),
        xl.BoolCellValue(true),
        xl.TextCellValue('Main Dishes'),
        xl.TextCellValue('Pork Sisig'),
      ]);
      modSheet.appendRow([
        xl.TextCellValue('mod-spice'),
        xl.TextCellValue('Spice Level'),
        xl.TextCellValue('spicy'),
        xl.TextCellValue('Extra Spicy'),
        xl.DoubleCellValue(15.0),
        xl.IntCellValue(1),
        xl.IntCellValue(1),
        xl.BoolCellValue(false),
        xl.BoolCellValue(true),
        xl.TextCellValue('Main Dishes'),
        xl.TextCellValue('Pork Sisig'),
      ]);

      modSheet.appendRow([
        xl.TextCellValue('mod-egg'),
        xl.TextCellValue('Egg Add-on'),
        xl.TextCellValue('egg-raw'),
        xl.TextCellValue('Raw Egg'),
        xl.DoubleCellValue(20.0),
        xl.IntCellValue(0),
        xl.IntCellValue(1),
        xl.BoolCellValue(false),
        xl.BoolCellValue(true),
        xl.TextCellValue(''),
        xl.TextCellValue(''),
      ]);

      final parsed = parseMenuWorkbook(excel);

      expect(parsed.products.length, 1);
      expect(parsed.products.first.name, 'Pork Sisig');
      expect(parsed.modifierGroups.length, 2);

      final spiceGroup = parsed.modifierGroups.firstWhere((g) => g.id == 'mod-spice');
      expect(spiceGroup.name, 'Spice Level');
      expect(spiceGroup.minSelected, 1);
      expect(spiceGroup.maxSelected, 1);
      expect(spiceGroup.options.length, 2);
      expect(spiceGroup.options[1].name, 'Extra Spicy');
      expect(spiceGroup.options[1].priceDelta, 15.0);
      expect(spiceGroup.targetCategoryIds, contains('cat-mains'));
    });
  });

  group('Admin Customizations UI Tests', () {
    testWidgets('Customizations view renders groups and opens Add Group dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Customizations in sidebar
      await tester.tap(find.text('Customizations'));
      await tester.pumpAndSettle();

      // Check view header and cards
      expect(find.text('Customizations'), findsWidgets);
      expect(find.text('Dynamic modifier groups, add-ons, sizes, and menu options'), findsOneWidget);
      expect(find.text('Total Groups'), findsOneWidget);
      expect(find.text('Active Groups'), findsOneWidget);
      expect(find.text('Total Options'), findsOneWidget);

      // Verify existing groups are rendered
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Milk Alternative'), findsOneWidget);
      expect(find.text('Rice Type'), findsOneWidget);
      expect(find.text('Extra Toppings'), findsOneWidget);

      // Tap 'Add Group'
      await tester.tap(find.widgetWithText(FilledButton, 'Add Group').first);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Add Customization Group'), findsOneWidget);
      expect(find.text('Group Name'), findsOneWidget);
      expect(find.text('Single Choice'), findsOneWidget);
      expect(find.text('Multiple Choice'), findsOneWidget);
      expect(find.text('Apply to Categories'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add Customization Group'), findsNothing);
    });
  });

  group('Cashier Customization Workflow Tests', () {
    testWidgets('Ordering flow enforces single-choice and multi-choice selections with prices', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CashierDashboard(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Iced Latte to customize
      await tester.tap(find.text('Iced Latte'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Customize Iced Latte'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Milk Alternative'), findsOneWidget);
      // Rice Bowls groups should NOT be present for latte
      expect(find.text('Rice Type'), findsNothing);
      expect(find.text('Extra Toppings'), findsNothing);

      // Regular is default selected. Select Large (+₱30.00)
      await tester.tap(find.text('Large +₱30.00'));
      await tester.pumpAndSettle();

      // Select Oat Milk (+₱40.00)
      await tester.tap(find.text('Oat Milk +₱40.00'));
      await tester.pumpAndSettle();

      // Tap 'Add to cart'
      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();

      // Item should be in cart
      expect(controller.cart.length, 1);
      final item = controller.cart.first;
      expect(item.product.name, 'Iced Latte');
      expect(item.selectedModifiers.map((m) => m.label), containsAll(['Large', 'Oat Milk']));
      // Base: 150 + 30 + 40 = 220
      expect(item.singleItemPrice, 220.0);
    });
  });
}
