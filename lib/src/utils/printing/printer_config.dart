import 'package:flutter/foundation.dart';

/// Supported paper roll widths.
enum PaperWidth {
  mm50(50, 26),
  mm58(58, 32),
  mm80(80, 48);

  const PaperWidth(this.millimeterWidth, this.defaultCharactersPerLine);

  final int millimeterWidth;
  final int defaultCharactersPerLine;

  double get printableWidthMm => switch (this) {
        PaperWidth.mm50 => 42.0,
        PaperWidth.mm58 => 48.0,
        PaperWidth.mm80 => 72.0,
      };

  static PaperWidth fromInt(int width) {
    return switch (width) {
      50 => PaperWidth.mm50,
      58 => PaperWidth.mm58,
      _ => PaperWidth.mm80,
    };
  }
}

/// Transport mechanisms for sending print jobs.
enum ThermalTransport {
  /// Direct print to system printer / CUPS spooler with zero UI dialog prompt.
  direct('Direct print (no prompt)'),

  /// System dialog (Android PrintManager / iOS AirPrint / Browser Print).
  systemDialog('System dialog'),

  /// Android share sheet to thermal printer helper apps (e.g. RawBT, PrinterShare).
  thermalApp('Thermal printer app'),

  /// Direct raw ESC/POS over TCP network socket (e.g. 192.168.1.100:9100).
  networkEscPos('Network (ESC/POS)'),

  /// Local HTTP/WebSocket print bridge daemon (e.g. http://localhost:8080/print).
  localBridge('Local print bridge (web)');

  const ThermalTransport(this.label);

  final String label;

  static ThermalTransport fromString(String? value) {
    if (value == null) return ThermalTransport.direct;
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('bridge')) {
      return ThermalTransport.localBridge;
    }
    if (normalized.contains('direct') ||
        normalized.contains('no prompt') ||
        normalized.contains('silent') ||
        normalized.contains('auto')) {
      return ThermalTransport.direct;
    }
    if (normalized.contains('network') ||
        normalized.contains('esc/pos') ||
        normalized.contains('escpos')) {
      return ThermalTransport.networkEscPos;
    }
    if (normalized.contains('thermal') ||
        normalized.contains('app') ||
        normalized.contains('rawbt')) {
      return ThermalTransport.thermalApp;
    }
    if (normalized.contains('system') || normalized.contains('dialog')) {
      return ThermalTransport.systemDialog;
    }
    return ThermalTransport.direct;
  }
}

/// Configuration settings for an 80mm / thermal printer.
@immutable
class PrinterConfig {
  const PrinterConfig({
    this.paperWidth = PaperWidth.mm80,
    int? charactersPerLine,
    this.transport = ThermalTransport.direct,
    this.printerName = 'GEZHI_micro_printer',
    this.printerUrl = '',
    this.feedLines = 2,
    this.autoCut = true,
    this.openCashDrawer = false,
    this.compactReceiptStyle = false,
    this.webKioskPrinting = false,
  }) : _charactersPerLine = charactersPerLine;

  final PaperWidth paperWidth;

  final int? _charactersPerLine;

  /// Effective characters per line (e.g. 32 for 58mm Font A, 48 for 80mm Font A).
  int get charactersPerLine =>
      _charactersPerLine ?? paperWidth.defaultCharactersPerLine;

  final ThermalTransport transport;
  final String printerName;

  /// URL or IP:port (e.g. "192.168.1.100:9100", local bridge URL, or printer identifier).
  final String printerUrl;

  /// Paper feed lines before cutter. Minimized to avoid wasting paper.
  final int feedLines;

  /// Whether to issue a paper cut command at the end of the receipt.
  final bool autoCut;

  /// Whether to issue a cash drawer kick command.
  final bool openCashDrawer;

  /// When true, renders tighter spacing and fonts.
  final bool compactReceiptStyle;

  /// When running on Web with Chrome launched via --kiosk-printing, enables silent printing.
  final bool webKioskPrinting;

  PrinterConfig copyWith({
    PaperWidth? paperWidth,
    int? charactersPerLine,
    ThermalTransport? transport,
    String? printerName,
    String? printerUrl,
    int? feedLines,
    bool? autoCut,
    bool? openCashDrawer,
    bool? compactReceiptStyle,
    bool? webKioskPrinting,
  }) {
    return PrinterConfig(
      paperWidth: paperWidth ?? this.paperWidth,
      charactersPerLine: charactersPerLine ?? _charactersPerLine,
      transport: transport ?? this.transport,
      printerName: printerName ?? this.printerName,
      printerUrl: printerUrl ?? this.printerUrl,
      feedLines: feedLines ?? this.feedLines,
      autoCut: autoCut ?? this.autoCut,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      compactReceiptStyle: compactReceiptStyle ?? this.compactReceiptStyle,
      webKioskPrinting: webKioskPrinting ?? this.webKioskPrinting,
    );
  }
}
