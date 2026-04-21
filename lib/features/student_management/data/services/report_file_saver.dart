import 'dart:typed_data';

import 'report_file_saver_io.dart'
    if (dart.library.html) 'report_file_saver_web.dart' as impl;

Future<String?> saveGeneratedReport({
  required String suggestedName,
  required Uint8List bytes,
  required String formatLabel,
  required String extension,
  required String mimeType,
}) {
  return impl.saveGeneratedReport(
    suggestedName: suggestedName,
    bytes: bytes,
    formatLabel: formatLabel,
    extension: extension,
    mimeType: mimeType,
  );
}
