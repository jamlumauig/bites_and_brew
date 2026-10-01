import 'package:printing/printing.dart';

/// Resolves a system printer by URL or name.
class PrinterResolver {
  const PrinterResolver._();

  /// Known keywords identifying thermal receipt printers.
  static const List<String> thermalKeywords = [
    'gezhi',
    'micro-printer',
    'micro_printer',
    'officom',
    'xp-80',
    'xp80',
    'pos-80',
    'pos80',
    'pos-58',
    'pos58',
    'pos',
    'thermal',
    'receipt',
    'xprinter',
    'zywell',
    'sunmi',
    'netum',
    'epson',
    '80mm',
    '58mm',
  ];

  static Future<Printer?> resolve(String printerUrl, String printerName) async {
    List<Printer> printers;
    try {
      printers = await Printing.listPrinters();
    } catch (_) {
      return null;
    }
    if (printers.isEmpty) {
      return null;
    }

    final normalizedUrl = printerUrl.trim();
    if (normalizedUrl.isNotEmpty) {
      for (final printer in printers) {
        if (printer.url == normalizedUrl) {
          return printer;
        }
      }
    }

    final normalizedName = printerName.trim().toLowerCase();
    final canonicalTarget = _canonical(normalizedName);
    if (normalizedName.isNotEmpty) {
      // 1. Exact match on name or url
      for (final printer in printers) {
        final cName = printer.name.toLowerCase();
        final cUrl = printer.url.toLowerCase();
        if (cName == normalizedName || cUrl == normalizedName) {
          return printer;
        }
      }

      // 2. Canonical match (ignores underscores, hyphens, spaces: e.g. "GEZHI_micro_printer" vs "GEZHI micro-printer")
      if (canonicalTarget.isNotEmpty) {
        for (final printer in printers) {
          final canonName = _canonical(printer.name);
          final canonUrl = _canonical(printer.url);
          if (canonName == canonicalTarget || canonUrl == canonicalTarget) {
            return printer;
          }
        }
      }

      // 3. Substring match
      for (final printer in printers) {
        final candidate = printer.name.toLowerCase();
        final cUrl = printer.url.toLowerCase();
        if (candidate.contains(normalizedName) ||
            normalizedName.contains(candidate) ||
            cUrl.contains(normalizedName)) {
          return printer;
        }
      }
    }

    return autoDetectPrinter(printers);
  }

  static String _canonical(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Automatically picks the best connected thermal printer, system default, or first available.
  static Printer? autoDetectPrinter(List<Printer> printers) {
    if (printers.isEmpty) return null;

    // 1. Try to find a printer matching known thermal keywords
    for (final printer in printers) {
      final name = printer.name.toLowerCase();
      final url = printer.url.toLowerCase();
      for (final keyword in thermalKeywords) {
        if (name.contains(keyword) || url.contains(keyword)) {
          return printer;
        }
      }
    }

    // 2. Default printer
    for (final printer in printers) {
      if (printer.isDefault) {
        return printer;
      }
    }

    // 3. Fallback to first printer
    return printers.first;
  }

  static String sanitizeFileName(String storeName, String orderId, String printerName) {
    final sSlug = _slugify(storeName);
    final pSlug = _slugify(printerName);
    return '${sSlug}_receipt_${orderId}_$pSlug.pdf';
  }

  static String _slugify(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return normalized.isEmpty ? 'receipt' : normalized.replaceAll(RegExp(r'_+'), '_');
  }
}

