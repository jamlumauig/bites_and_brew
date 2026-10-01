import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cafe_and_brews/src/ui/widgets/cashier_dashboard.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/android_printer_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/utils/receipt_printer.dart';
import 'package:cafe_and_brews/src/utils/printing/platform_adapters/platform_printer_adapter.dart';
import 'package:cafe_and_brews/src/utils/printing/web_receipt_html_builder.dart';

class CountingRepository extends InMemoryCoffeePosRepository {
  int creations = 0;
  @override
  Future<OrderRecord> createOrder(
    OrderDraft draft, {
    int? sequence,
    String? orderId,
  }) {
    creations++;
    return super.createOrder(draft, sequence: sequence, orderId: orderId);
  }
}

class CapturingAdapter implements PlatformPrinterAdapter {
  int submissions = 0;
  late ReceiptData receipt;
  late Uint8List pdf;
  late Uint8List raw;
  @override
  Future<PrintResult> printReceipt({
    required String jobId,
    required ReceiptData receipt,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    submissions++;
    this.receipt = receipt;
    pdf = pdfBytes;
    raw = escPosBytes;
    return PrintResult(
      jobId: jobId,
      receiptId: receipt.orderId,
      status: PrintStatus.success,
    );
  }

  @override
  Future<PrintResult> printPreparationTicket({
    required String jobId,
    required PreparationTicketData ticket,
    required PrinterConfig config,
    required Uint8List pdfBytes,
    required Uint8List escPosBytes,
  }) async {
    submissions++;
    throw StateError('Checkout must never submit a separate kitchen job');
  }

  @override
  Future<bool> isPrinterAvailable(PrinterConfig config) async => true;
}

class FailingKitchenBuilder extends PdfReceiptBuilder {
  FailingKitchenBuilder(PrinterConfig config) : super(config: config);
  @override
  Future<Uint8List> buildPdfBytes(ReceiptData receipt) async {
    if (receipt.preparationTicket != null) {
      throw StateError('Kitchen generation failed');
    }
    return super.buildPdfBytes(receipt);
  }
}

class CountingSystemPrinting extends PrintingPlatform {
  @override
  Future<List<Printer>> listPrinters() async => [];

  int calls = 0;
  late Uint8List payload;
  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
  ) async {
    calls++;
    payload = await onLayout(format);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReceiptData packageFixture(int count, {bool invalidKitchen = false}) {
  final createdAt = DateTime(2026, 10, 1, 15, 31);
  return ReceiptData(
    orderId: 'ORDER-83',
    sequence: 83,
    orderType: 'Dine-in',
    paymentType: 'CARD',
    cashierName: 'Jam',
    createdAt: createdAt,
    storeName: 'HAVEN & CO.',
    storeAddress: '',
    storeContact: '',
    receiptHeader: '',
    receiptFooter: 'Thank you!',
    items: List.generate(
      count,
      (_) => const ReceiptItem(
        name: 'Cappuccino',
        quantity: 1,
        unitPrice: 105,
        lineTotal: 105,
      ),
    ),
    subtotal: count * 105.0,
    discount: 0,
    tax: 0,
    serviceCharge: 0,
    total: count * 105.0,
    cashReceived: 0,
    change: 0,
    vatEnabled: false,
    preparationTicket: PreparationTicketData(
      orderId: 'ORDER-83',
      sequence: 83,
      orderType: 'Dine-in',
      createdAt: createdAt,
      note: invalidKitchen ? 'Exception: kitchen failed' : '',
      items: List.generate(
        count,
        (_) => const PreparationTicketItem(
          name: 'Cappuccino',
          quantity: 1,
          modifierLabels: ['16 oz', 'Oat Milk', 'Extra Shot'],
        ),
      ),
    ),
  );
}

double pdfHeight(Uint8List bytes) {
  final match = RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+[\d.]+\s+([\d.]+)\s*\]',
  ).firstMatch(latin1.decode(bytes));
  return double.parse(match!.group(1)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThermalPrinterService previous;
  setUp(() {
    previous = ThermalPrinterService.instance;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => ThermalPrinterService.instance = previous);

  for (final transport in ['System dialog', 'Network ESC/POS']) {
    for (final autoCut in [false, true]) {
      test(
        'One charge: one order and one combined $transport submission, autoCut=$autoCut',
        () async {
          final adapter = CapturingAdapter();
          ThermalPrinterService.instance = ThermalPrinterServiceImpl(
            adapter: adapter,
          );
          final repository = CountingRepository();
          final controller = CoffeePosController(repository: repository);
          addTearDown(controller.dispose);
          await controller.initialize();
          controller.updatePrinterSettings(
            printerName: 'Primary',
            printerUrl: '',
            autoPrintReceipts: true,
            thermalAutoCut: autoCut,
          );
          controller.addProductToCart(controller.products.first);
          controller.updateCashReceived(1000);
          final order = await controller.checkout();
          expect(order, isNotNull);
          final result = await controller.printOrderPackage(
            order!,
            transportOverride: transport,
          );
          expect(result.isSuccess, isTrue);
          expect(repository.creations, 1);
          expect(adapter.submissions, 1);
          expect(adapter.receipt.preparationTicket!.sequence, order.sequence);

          final config = PrinterConfig(autoCut: autoCut);
          final raw = utf8.decode(adapter.raw);
          final kitchen = raw.indexOf('ORDER #');
          expect(raw.indexOf('TOTAL'), lessThan(kitchen));
          expect(raw.substring(kitchen), isNot(contains('TOTAL')));
          expect(raw.substring(kitchen), isNot(contains('VAT')));
          if (autoCut) {
            expect('\x1d\x56\x42\x00'.allMatches(raw).length, 2);
            expect(raw.indexOf('\x1d\x56\x42\x00'), lessThan(kitchen));
          } else {
            final plain = raw.replaceAll(RegExp(r'\x1b[@]|\x1b[aEd].'), '');
            expect(plain, contains('\n\n\nORDER #'));
            expect(raw, isNot(contains('\x1d\x56\x42\x00')));
          }
          final html = WebReceiptHtmlBuilder.buildReceiptHtml(
            adapter.receipt,
            config: config,
          );
          expect('<html'.allMatches(html).length, 1);
          expect(html.indexOf('TOTAL'), lessThan(html.indexOf('ORDER #')));
          expect(html, isNot(contains('CUT HERE')));
          expect(html, isNot(contains('END OF ORDER')));
          final pdf = latin1.decode(adapter.pdf);
          expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 1);
          expect(pdf, isNot(contains('Infinity')));

          await controller.printOrderPackage(order); // rapid repeat blocked
          expect(adapter.submissions, 1);
          await controller.printReceipt(
            order,
            manualReprint: true,
          ); // history only
          expect(adapter.submissions, 2);
          expect(adapter.receipt.preparationTicket, isNull);
          expect(repository.creations, 1);
        },
      );
    }
  }

  test(
    'Native system adapter invokes the PDF plugin once for a combined order',
    () async {
      final platform = CountingSystemPrinting();
      final original = PrintingPlatform.instance;
      PrintingPlatform.instance = platform;
      addTearDown(() => PrintingPlatform.instance = original);
      ThermalPrinterService.instance = ThermalPrinterServiceImpl(
        adapter: const AndroidPrinterAdapter(),
      );
      final repository = CountingRepository();
      final controller = CoffeePosController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize();
      controller.addProductToCart(controller.products.first);
      controller.updateCashReceived(1000);
      final order = await controller.checkout();
      final result = await controller.printOrderPackage(
        order!,
        transportOverride: 'System dialog',
      );
      expect(result.isSuccess, isTrue);
      expect(repository.creations, 1);
      expect(platform.calls, 1);
      expect(
        RegExp(
          r'/Type\s*/Page\b',
        ).allMatches(latin1.decode(platform.payload)).length,
        1,
      );
    },
  );

  testWidgets('Tapping Charge creates one order and submits one package', (
    tester,
  ) async {
    final originalPlatform = PrintingPlatform.instance;
    PrintingPlatform.instance = CountingSystemPrinting();
    addTearDown(() => PrintingPlatform.instance = originalPlatform);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = CapturingAdapter();
    ThermalPrinterService.instance = ThermalPrinterServiceImpl(
      adapter: adapter,
    );
    final repository = CountingRepository();
    final controller = CoffeePosController(repository: repository);
    addTearDown(controller.dispose);
    final initialized = controller.initialize();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await initialized;
    controller.updatePrinterSettings(
      printerName: 'Primary',
      printerUrl: '',
      autoPrintReceipts: true,
    );
    controller.addProductToCart(controller.products.first);
    controller.updateCashReceived(1000);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CashierDashboard(controller: controller)),
      ),
    );
    await tester.tap(find.text('Charge'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repository.creations, 1);
    expect(adapter.submissions, 1);
    expect(adapter.receipt.preparationTicket, isNotNull);
    expect(utf8.decode(adapter.raw), contains('ORDER #'));
    expect(utf8.decode(adapter.raw), isNot(contains('END OF ORDER')));
  });

  test('Invalid kitchen data prevents every submission', () async {
    final adapter = CapturingAdapter();
    final service = ThermalPrinterServiceImpl(adapter: adapter);
    final result = await service.printReceipt(
      packageFixture(1, invalidKitchen: true),
    );
    expect(result.status, PrintStatus.failedBeforeSending);
    expect(adapter.submissions, 0);
  });

  test(
    'Combined PDF grows with both sections on one continuous 58mm page',
    () async {
      const builder = PdfReceiptBuilder(
        config: PrinterConfig(paperWidth: PaperWidth.mm58),
      );
      final small = await builder.buildPdfBytes(packageFixture(1));
      final large = await builder.buildPdfBytes(packageFixture(60));
      expect(pdfHeight(large), greaterThan(pdfHeight(small)));
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(large)).length,
        1,
      );
    },
  );

  test(
    'Kitchen generation failure sends nothing and leaves one saved order',
    () async {
      final adapter = CapturingAdapter();
      ThermalPrinterService.instance = ThermalPrinterServiceImpl(
        adapter: adapter,
        pdfBuilderFactory: FailingKitchenBuilder.new,
      );
      final repository = CountingRepository();
      final controller = CoffeePosController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize();
      controller.addProductToCart(controller.products.first);
      controller.updateCashReceived(1000);
      final order = await controller.checkout();
      final result = await controller.printOrderPackage(order!);
      expect(result.status, PrintStatus.failedBeforeSending);
      expect(adapter.submissions, 0);
      expect(repository.creations, 1);
    },
  );
}
