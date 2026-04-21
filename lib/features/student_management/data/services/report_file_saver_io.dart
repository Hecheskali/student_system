import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<String?> saveGeneratedReport({
  required String suggestedName,
  required Uint8List bytes,
  required String formatLabel,
  required String extension,
  required String mimeType,
}) async {
  final FileSaveLocation? location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: <XTypeGroup>[
      XTypeGroup(label: formatLabel, extensions: <String>[extension]),
    ],
  );

  if (location == null) {
    return null;
  }

  final XFile file = XFile.fromData(
    bytes,
    mimeType: mimeType,
    name: suggestedName,
  );
  await file.saveTo(location.path);
  return location.path;
}
