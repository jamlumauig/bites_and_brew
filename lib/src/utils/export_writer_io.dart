import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveBytesToDownloads({
  required List<int> bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) async {
  final directory = await _resolveDownloadsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
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

Future<Directory> _resolveDownloadsDirectory() async {
  final publicDownload = _androidPublicDownloadsDirectory();
  if (publicDownload != null) {
    try {
      await publicDownload.create(recursive: true);
      return publicDownload;
    } on FileSystemException {
      // Fall through to platform-specific resolution.
    }
  }

  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      await downloads.create(recursive: true);
      return downloads;
    }
  } on MissingPluginException {
    // The plugin is not registered in this runtime. Fall back below.
  } on UnsupportedError {
    // Fall back below.
  } on FileSystemException {
    // Fall back below.
  }

  try {
    final documents = await getApplicationDocumentsDirectory();
    final fallback = Directory(
      '${documents.path}${Platform.pathSeparator}Downloads',
    );
    await fallback.create(recursive: true);
    return fallback;
  } on MissingPluginException {
    // Fall back below.
  }

  final fallback = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}bites-brew-downloads',
  );
  await fallback.create(recursive: true);
  return fallback;
}

Directory? _androidPublicDownloadsDirectory() {
  if (!Platform.isAndroid) {
    return null;
  }
  return const [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/sdcard/Download',
  ]
      .map(Directory.new)
      .firstWhere(
        (directory) => true,
        orElse: () => Directory('/storage/emulated/0/Download'),
      );
}
