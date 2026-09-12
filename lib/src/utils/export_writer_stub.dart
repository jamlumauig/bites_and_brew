Future<String> saveBytesToDownloads({
  required List<int> bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('File export is not supported on this platform.');
}

Future<String> saveTextToDownloads({
  required String text,
  required String fileName,
  String mimeType = 'text/plain',
}) {
  throw UnsupportedError('File export is not supported on this platform.');
}
