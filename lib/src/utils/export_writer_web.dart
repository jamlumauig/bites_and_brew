import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> saveBytesToDownloads({
  required List<int> bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) async {
  final blobParts = <Object?>[bytes.jsify()].jsify()! as JSArray<web.BlobPart>;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  Timer(const Duration(seconds: 1), () {
    anchor.remove();
    web.URL.revokeObjectURL(url);
  });
  return fileName;
}

Future<String> saveTextToDownloads({
  required String text,
  required String fileName,
  String mimeType = 'text/plain',
}) async {
  return saveBytesToDownloads(
    bytes: utf8.encode(text),
    fileName: fileName,
    mimeType: mimeType,
  );
}
