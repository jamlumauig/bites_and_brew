import 'package:excel/excel.dart' as xl;

import '../domain/coffee_pos_models.dart';

/// A fully validated menu. Parsing does not mutate the live catalog.
class ImportedMenu {
  const ImportedMenu({
    required this.categories,
    required this.products,
    required this.modifierGroups,
  });
  final List<Category> categories;
  final List<Product> products;
  final List<ModifierGroup> modifierGroups;
}

ImportedMenu parseMenuWorkbook(
  xl.Excel workbook, {
  List<ModifierGroup> existingGroups = const [],
}) {
  final sheet =
      workbook.tables['Products'] ??
      workbook.tables[workbook.getDefaultSheet()] ??
      workbook.tables.values.firstOrNull;
  if (sheet == null) {
    throw const FormatException('No Products worksheet found.');
  }
  final rows = _rows(sheet);
  if (rows.length < 2) {
    throw const FormatException(
      'Include a header row and at least one product.',
    );
  }
  final header = _Header(rows.first);
  final nameColumn = header.required(['name', 'product name']);
  final priceColumn = header.required(['price', 'product price']);
  final groups = {for (final group in existingGroups) group.id: group};
  final modifiersSheet = workbook.tables['Modifiers'];
  if (modifiersSheet != null) {
    for (final group in _parseGroups(modifiersSheet)) {
      groups[group.id] = group;
    }
  }
  final categories = <String, Category>{};
  final products = <Product>[];
  final usedIds = <String>{};
  final usedGroups = <String>{};
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final name = _cell(row, nameColumn);
    if (name.isEmpty) continue;
    final price = double.tryParse(_cell(row, priceColumn));
    if (price == null || !price.isFinite || price < 0) {
      throw FormatException('Row ${i + 1}: enter a valid non-negative Price.');
    }
    final categoryName = header.read(row, ['category name', 'category']);
    final explicitCategoryId = header.read(row, ['category id', 'categoryid']);
    final categoryId = explicitCategoryId.isNotEmpty
        ? explicitCategoryId
        : categoryName.isNotEmpty
        ? categoryName.toLowerCase()
        : 'uncategorized';
    final category = Category(
      id: categoryId,
      name: categoryName.isNotEmpty
          ? categoryName
          : explicitCategoryId.isNotEmpty
          ? explicitCategoryId
          : 'Uncategorized',
      icon: header.read(row, ['category icon', 'icon']),
    );
    final previous = categories[categoryId];
    if (previous != null && previous.name != category.name) {
      throw FormatException(
        'Row ${i + 1}: conflicting names for category $categoryId.',
      );
    }
    categories[categoryId] = category;
    final rawId = header.read(row, ['product id', 'id']);
    final baseId = rawId.isEmpty ? name.toLowerCase() : rawId;
    var id = baseId;
    var suffix = 2;
    while (!usedIds.add(id)) {
      id = '$baseId-${suffix++}';
    }
    final rawGroupTokens = header
        .read(row, [
          'modifier group ids',
          'modifier group',
          'modifier groups',
          'customizations',
          'add-ons',
        ])
        .split(RegExp(r'[,;\n]'))
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final groupIds = <String>[];
    for (final token in rawGroupTokens) {
      ModifierGroup? matched;
      for (final g in groups.values) {
        if (g.id.toLowerCase() == token.toLowerCase() ||
            g.name.toLowerCase() == token.toLowerCase()) {
          matched = g;
          break;
        }
      }
      matched ??= groups[token];
      if (matched == null) {
        throw FormatException(
          'Row ${i + 1}: unknown modifier group "$token". Add its options to the Modifiers sheet.',
        );
      }
      groupIds.add(matched.id);
      usedGroups.add(matched.id);
    }
    final image = header.read(row, ['image url', 'image', 'photo url']);
    products.add(
      Product(
        id: id,
        name: name,
        categoryId: categoryId,
        price: price,
        description: header.read(row, ['description']),
        badge: header.read(row, ['badge']),
        modifierGroupIds: groupIds,
        useCategoryDefaults: false,
        imageUrl: image.isEmpty ? null : image,
        isAvailable: _boolean(
          header.read(row, ['available', 'availability', 'is available']),
          defaultValue: true,
          label: 'Row ${i + 1}: Available',
        ),
      ),
    );
  }
  if (products.isEmpty) throw const FormatException('No product rows found.');
  final normalizedGroups = groups.values.map((group) {
    final mappedCategoryIds = group.targetCategoryIds.map((token) {
      final matched = categories.values.where(
        (c) => c.id.toLowerCase() == token.toLowerCase() ||
               c.name.toLowerCase() == token.toLowerCase(),
      ).firstOrNull;
      return matched?.id ?? token;
    }).toSet().toList();

    final mappedProductIds = group.targetProductIds.map((token) {
      final matched = products.where(
        (p) => p.id.toLowerCase() == token.toLowerCase() ||
               p.name.toLowerCase() == token.toLowerCase(),
      ).firstOrNull;
      return matched?.id ?? token;
    }).toSet().toList();

    return group.copyWith(
      targetCategoryIds: mappedCategoryIds,
      targetProductIds: mappedProductIds,
    );
  }).toList();

  return ImportedMenu(
    categories: categories.values.toList(),
    products: products,
    modifierGroups: normalizedGroups,
  );
}

List<ModifierGroup> _parseGroups(xl.Sheet sheet) {
  final rows = _rows(sheet);
  if (rows.isEmpty) return [];
  final header = _Header(rows.first);
  final groupColumn = header.required(['group id']);
  final optionColumn = header.required(['option name']);
  final groups = <String, ModifierGroup>{};
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final id = _cell(row, groupColumn);
    final name = _cell(row, optionColumn);
    if (id.isEmpty || name.isEmpty) {
      throw FormatException(
        'Modifiers row ${i + 1}: Group ID and Option Name are required.',
      );
    }
    final deltaText = header.read(row, ['price delta', 'additional price']);
    final delta = deltaText.isEmpty ? 0.0 : double.tryParse(deltaText);
    final minText = header.read(row, ['min selected', 'minimum']);
    final maxText = header.read(row, ['max selected', 'maximum']);
    final min = minText.isEmpty ? 0 : int.tryParse(minText);
    final max = maxText.isEmpty ? 1 : int.tryParse(maxText);
    if (delta == null ||
        !delta.isFinite ||
        delta < 0 ||
        min == null ||
        max == null ||
        min < 0 ||
        max < 0 ||
        (max != 0 && max < min)) {
      throw FormatException(
        'Modifiers row ${i + 1}: invalid price or selection limits.',
      );
    }
    final groupName = header.read(row, ['group name']);
    final previous = groups[id];
    if (previous != null &&
        (previous.minSelected != min ||
            previous.maxSelected != max ||
            previous.name != (groupName.isEmpty ? id : groupName))) {
      throw FormatException(
        'Modifiers row ${i + 1}: use consistent group names and selection limits.',
      );
    }
    final optionId = header.read(row, ['option id']);
    final resolvedOptionId = optionId.isEmpty ? name : optionId;
    if (previous?.options.any((option) => option.id == resolvedOptionId) ??
        false) {
      throw FormatException('Modifiers row ${i + 1}: duplicate Option ID.');
    }
    final enabledText = header.read(row, ['enabled', 'active', 'is active']);
    final isEnabled = enabledText.isEmpty
        ? true
        : _boolean(
            enabledText,
            defaultValue: true,
            label: 'Modifiers row ${i + 1}: Enabled',
          );
    final targetCategoriesText = header.read(row, [
      'assigned categories',
      'target categories',
      'categories',
      'category ids',
    ]);
    final targetCategories = targetCategoriesText
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final targetProductsText = header.read(row, [
      'assigned products',
      'target products',
      'products',
      'product ids',
    ]);
    final targetProducts = targetProductsText
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    groups[id] = ModifierGroup(
      id: id,
      name: groupName.isEmpty ? id : groupName,
      minSelected: min,
      maxSelected: max,
      enabled: isEnabled,
      targetCategoryIds: {
        ...?previous?.targetCategoryIds,
        ...targetCategories,
      }.toList(),
      targetProductIds: {
        ...?previous?.targetProductIds,
        ...targetProducts,
      }.toList(),
      options: [
        ...?previous?.options,
        ModifierOption(
          id: resolvedOptionId,
          name: name,
          priceDelta: delta,
          isDefault: _boolean(
            header.read(row, ['default', 'is default']),
            defaultValue: false,
            label: 'Modifiers row ${i + 1}: Default',
          ),
        ),
      ],
    );
  }
  for (final group in groups.values) {
    if (group.minSelected > group.options.length) {
      throw FormatException(
        'Group ${group.name}: minimum exceeds available options.',
      );
    }
  }
  return groups.values.toList();
}

bool _boolean(
  String value, {
  required bool defaultValue,
  required String label,
}) {
  switch (value.toLowerCase()) {
    case '':
      return defaultValue;
    case 'yes':
    case 'true':
    case '1':
    case 'available':
    case 'in stock':
      return true;
    case 'no':
    case 'false':
    case '0':
    case 'unavailable':
    case 'sold out':
    case 'out of stock':
      return false;
    default:
      throw FormatException('$label must be Yes or No.');
  }
}

List<List<xl.Data?>> _rows(xl.Sheet sheet) => sheet.rows
    .where((row) => row.any((cell) => _text(cell).isNotEmpty))
    .toList();
String _cell(List<xl.Data?> row, int index) =>
    index < row.length ? _text(row[index]) : '';
String _text(xl.Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is xl.TextCellValue) return value.value.toString().trim();
  if (value is xl.IntCellValue) return value.value.toString();
  if (value is xl.DoubleCellValue) return value.value.toString();
  if (value is xl.BoolCellValue) return value.value.toString();
  return value.toString().trim();
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

class _Header {
  _Header(List<xl.Data?> row)
    : columns = {
        for (var i = 0; i < row.length; i++) _normalize(_text(row[i])): i,
      };
  final Map<String, int> columns;
  int? find(List<String> aliases) {
    for (final alias in aliases) {
      final index = columns[_normalize(alias)];
      if (index != null) return index;
    }
    return null;
  }

  int required(List<String> aliases) =>
      find(aliases) ??
      (throw FormatException('Missing required column: ${aliases.first}.'));
  String read(List<xl.Data?> row, List<String> aliases) {
    final index = find(aliases);
    return index == null ? '' : _cell(row, index);
  }
}
