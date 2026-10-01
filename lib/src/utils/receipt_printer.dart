import '../domain/coffee_pos_models.dart';
import 'printing/preparation_ticket_data.dart';
import 'printing/print_status.dart';
import 'printing/printer_config.dart';
import 'printing/receipt_data.dart';
import 'printing/thermal_printer_service.dart';

export 'printing/esc_pos_generator.dart';
export 'printing/pdf_receipt_builder.dart';
export 'printing/preparation_ticket_data.dart';
export 'printing/print_logger.dart';
export 'printing/print_status.dart';
export 'printing/printer_config.dart';
export 'printing/receipt_data.dart';
export 'printing/receipt_validator.dart';
export 'printing/thermal_printer_service.dart';

/// Legacy & top-level facade function for printing receipts.
///
/// Converts the domain [OrderRecord] to [ReceiptData], maps configuration,
/// and delegates to [ThermalPrinterService.instance.printReceipt] with queue
/// serialization, duplicate prevention, and zero-paper-waste validation.
Future<PrintResult> printReceipt({
  required OrderRecord order,
  required String storeName,
  required String storeAddress,
  required String storeContact,
  required String receiptHeader,
  required String receiptFooter,
  required String printerName,
  required String printerUrl,
  required bool compactReceiptStyle,
  required String thermalTransport,
  required int thermalPaperWidth,
  required int feedLines,
  bool autoCut = true,
  bool openCashDrawer = false,
  bool manualReprint = false,
  bool includeKitchen = false,
  bool webKioskPrinting = false,
}) {
  final receipt = ReceiptData.fromOrderRecord(
    order: order,
    includeKitchen: includeKitchen,
    storeName: storeName,
    storeAddress: storeAddress,
    storeContact: storeContact,
    receiptHeader: receiptHeader,
    receiptFooter: receiptFooter,
    printerName: printerName,
  );

  final config = PrinterConfig(
    paperWidth: PaperWidth.fromInt(thermalPaperWidth),
    transport: ThermalTransport.fromString(thermalTransport),
    printerName: printerName,
    printerUrl: printerUrl,
    feedLines: feedLines,
    autoCut: autoCut,
    openCashDrawer: openCashDrawer,
    compactReceiptStyle: compactReceiptStyle,
    webKioskPrinting: webKioskPrinting,
  );

  return ThermalPrinterService.instance.printReceipt(
    receipt,
    config: config,
    manualReprint: manualReprint,
  );
}

/// Facade function for printing kitchen/barista preparation tickets.
///
/// Excludes all financial data and prints with minimal paper length.
Future<PrintResult> printPreparationTicket({
  required PreparationTicketData ticket,
  required String printerName,
  required String printerUrl,
  required bool compactReceiptStyle,
  required String thermalTransport,
  required int thermalPaperWidth,
  required int feedLines,
  bool autoCut = true,
  bool webKioskPrinting = false,
}) {
  final config = PrinterConfig(
    paperWidth: PaperWidth.fromInt(thermalPaperWidth),
    transport: ThermalTransport.fromString(thermalTransport),
    printerName: printerName,
    printerUrl: printerUrl,
    feedLines: feedLines,
    autoCut: autoCut,
    compactReceiptStyle: compactReceiptStyle,
    webKioskPrinting: webKioskPrinting,
  );

  return ThermalPrinterService.instance.printPreparationTicket(
    ticket,
    config: config,
  );
}
