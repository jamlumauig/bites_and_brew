import 'network_printer_stub.dart'
    if (dart.library.js_interop) 'network_printer_web.dart'
    if (dart.library.html) 'network_printer_web.dart'
    if (dart.library.io) 'network_printer_io.dart' as client;

Future<bool> sendRawBytesToNetworkPrinter({
  required String host,
  required int port,
  required List<int> bytes,
  Duration timeout = const Duration(seconds: 5),
  void Function()? onTransmissionStarted,
}) {
  return client.sendRawBytesToNetworkPrinter(
    host: host,
    port: port,
    bytes: bytes,
    timeout: timeout,
    onTransmissionStarted: onTransmissionStarted,
  );
}

Future<bool> isNetworkPrinterReachable({
  required String host,
  required int port,
  Duration timeout = const Duration(seconds: 2),
}) {
  return client.isNetworkPrinterReachable(
    host: host,
    port: port,
    timeout: timeout,
  );
}

