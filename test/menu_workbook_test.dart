import 'package:cafe_and_brews/src/data/menu_workbook.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

xl.Excel workbook(List<List<String>> rows) {
  final book = xl.Excel.createExcel();
  for (final row in rows) {
    book['Products'].appendRow(row.map(xl.TextCellValue.new).toList());
  }
  return book;
}

void main() {
  test(
    'Excel imports arbitrary categories, image URLs, availability and prices without inferred options',
    () {
      final book = workbook([
        ['Name', 'Category', 'Price', 'Image URL', 'Available', 'Description'],
        [
          'Uploaded item',
          'A completely new category',
          '1234.56',
          'https://example.com/product.jpg',
          'No',
          'From Excel',
        ],
        ['Complimentary item', 'Another category', '0', '', 'Yes', ''],
      ]);
      final result = parseMenuWorkbook(xl.Excel.decodeBytes(book.encode()!));
      expect(result.categories.map((category) => category.name), [
        'A completely new category',
        'Another category',
      ]);
      expect(result.products.first.imageUrl, 'https://example.com/product.jpg');
      expect(result.products.first.price, 1234.56);
      expect(result.products.first.description, 'From Excel');
      expect(result.products.first.isAvailable, isFalse);
      expect(result.products.last.isAvailable, isTrue);
      expect(result.products.last.price, 0);
      expect(
        result.products.every((product) => !product.useCategoryDefaults),
        isTrue,
      );
    },
  );

  test(
    'uploaded options and add-on prices resolve without hardcoded group names',
    () {
      final book = workbook([
        ['Name', 'Category', 'Price', 'Modifier Group IDs'],
        ['Item', 'Custom', '100', 'option-group'],
      ]);
      for (final row in [
        [
          'Group ID',
          'Group Name',
          'Option ID',
          'Option Name',
          'Price Delta',
          'Min Selected',
          'Max Selected',
        ],
        [
          'option-group',
          'Uploaded variant',
          'one',
          'Choice one',
          '0',
          '1',
          '1',
        ],
        [
          'option-group',
          'Uploaded variant',
          'two',
          'Choice two',
          '25',
          '1',
          '1',
        ],
      ]) {
        book['Modifiers'].appendRow(row.map(xl.TextCellValue.new).toList());
      }
      final result = parseMenuWorkbook(book);
      expect(result.modifierGroups.single.name, 'Uploaded variant');
      expect(result.modifierGroups.single.options.last.priceDelta, 25);
      expect(result.products.single.modifierGroupIds, ['option-group']);
    },
  );

  test(
    'invalid prices, availability and unresolved options reject the workbook',
    () {
      for (final price in ['oops', '-1', 'NaN', 'Infinity']) {
        expect(
          () => parseMenuWorkbook(
            workbook([
              ['Name', 'Price'],
              ['Item', price],
            ]),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => parseMenuWorkbook(
          workbook([
            ['Name', 'Price', 'Available'],
            ['Item', '10', 'maybe'],
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => parseMenuWorkbook(
          workbook([
            ['Name', 'Price', 'Modifier Group IDs'],
            ['Item', '10', 'unknown'],
          ]),
        ),
        throwsFormatException,
      );
    },
  );

  test('same category ID reads new names from each uploaded workbook', () {
    final old = parseMenuWorkbook(
      workbook([
        ['Name', 'Price', 'Category ID', 'Category'],
        ['Item', '10', 'stable', 'Old name'],
      ]),
    );
    final updated = parseMenuWorkbook(
      workbook([
        ['Name', 'Price', 'Category ID', 'Category'],
        ['Item', '20', 'stable', 'New name'],
      ]),
    );
    expect(old.categories.single.name, 'Old name');
    expect(updated.categories.single.name, 'New name');
    expect(updated.products.single.price, 20);
  });
}
