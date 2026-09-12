import 'export_writer_stub.dart'
    if (dart.library.html) 'export_writer_web.dart'
    if (dart.library.io) 'export_writer_io.dart' as writer;

Future<String> saveBytesToDownloads({
  required List<int> bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  return writer.saveBytesToDownloads(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}

Future<String> saveTextToDownloads({
  required String text,
  required String fileName,
  String mimeType = 'text/plain',
}) {
  return writer.saveTextToDownloads(
    text: text,
    fileName: fileName,
    mimeType: mimeType,
  );
}
