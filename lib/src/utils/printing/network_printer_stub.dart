/// Default fallback stub for network printer socket operations.
library;

Future<bool> sendRawBytesToNetworkPrinter({
  required String host,
  required int port,
  required List<int> bytes,
  Duration timeout = const Duration(seconds: 5),
  void Function()? onTransmissionStarted,
}) async {
  throw UnsupportedError('Raw socket printing is not supported on this platform.');
}

Future<bool> isNetworkPrinterReachable({
  required String host,
  required int port,
  Duration timeout = const Duration(seconds: 2),
}) async {
  return false;
}
