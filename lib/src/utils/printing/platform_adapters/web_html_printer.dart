import 'web_html_printer_stub.dart'
    if (dart.library.js_interop) 'web_html_printer_web.dart'
    if (dart.library.html) 'web_html_printer_web.dart' as impl;

/// Cross-platform router for Web HTML iframe thermal printing.
Future<bool> printHtmlViaIframe(String htmlContent, {String? title}) {
  return impl.printHtmlViaIframe(htmlContent, title: title);
}

