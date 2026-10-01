import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web implementation of 80mm receipt printing via hidden iframe.
///
/// Sends the 80mm HTML/CSS layout directly to the browser print engine and
/// macOS CUPS spooler without requiring PDF conversion or raw ESC/POS sockets.
Future<bool> printHtmlViaIframe(String htmlContent, {String? title}) async {
  final blobParts =
      <Object?>[utf8.encode(htmlContent).jsify()].jsify()!
          as JSArray<web.BlobPart>;
  final blob = web.Blob(
    blobParts,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);

  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..src = url
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0';

  if (title != null && title.isNotEmpty) {
    iframe.title = title;
  }

  web.document.body?.append(iframe);

  final completer = Completer<bool>();

  void cleanup() {
    Timer(const Duration(seconds: 45), () {
      try {
        iframe.remove();
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    });
  }

  // Claim the invocation before calling print: a delayed load and fallback timer
  // must never submit the same document twice, even while a dialog is open.
  var printStarted = false;
  void printOnce() {
    if (printStarted) return;
    printStarted = true;
    try {
      final window = iframe.contentWindow;
      if (window == null) {
        completer.complete(false);
        return;
      }
      window.focus();
      window.print();
      completer.complete(true);
    } catch (_) {
      completer.complete(false);
    } finally {
      cleanup();
    }
  }

  iframe.onload = ((web.Event _) {
    Timer(const Duration(milliseconds: 150), printOnce);
  }).toJS;
  Timer(const Duration(milliseconds: 1200), printOnce);

  return completer.future;
}
