import 'dart:async';
import 'dart:io';

/// Native implementation of network printer operations using `dart:io`.
///
/// Sends raw ESC/POS byte streams directly to network-attached thermal printers
/// (typically over port 9100).
Future<bool> sendRawBytesToNetworkPrinter({
  required String host,
  required int port,
  required List<int> bytes,
  Duration timeout = const Duration(seconds: 5),
  void Function()? onTransmissionStarted,
}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    // Connection established; signal that transmission has started so errors
    // during write transition to unknown status rather than failedBeforeSending.
    onTransmissionStarted?.call();
    socket.add(bytes);
    await socket.flush();
    return true;
  } finally {
    try {
      await socket?.close();
    } catch (_) {}
    socket?.destroy();
  }
}

Future<bool> isNetworkPrinterReachable({
  required String host,
  required int port,
  Duration timeout = const Duration(seconds: 2),
}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    return true;
  } catch (_) {
    return false;
  } finally {
    try {
      await socket?.close();
    } catch (_) {}
    socket?.destroy();
  }
}

