/// Web implementation of network printer operations.
/// Browsers cannot open raw TCP sockets directly to local network printers.
library;

Future<bool> sendRawBytesToNetworkPrinter({
  required String host,
  required int port,
  required List<int> bytes,
  Duration timeout = const Duration(seconds: 5),
  void Function()? onTransmissionStarted,
}) async {
  throw UnsupportedError(
    'Raw TCP network printing is not supported in web browsers. '
    'Please use the System dialog (browser print) instead.',
  );
}

Future<bool> isNetworkPrinterReachable({
  required String host,
  required int port,
  Duration timeout = const Duration(seconds: 2),
}) async {
  return false;
}
