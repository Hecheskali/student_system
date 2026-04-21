// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:typed_data';
import 'dart:html' as html;

Future<String?> saveGeneratedReport({
  required String suggestedName,
  required Uint8List bytes,
  required String formatLabel,
  required String extension,
  required String mimeType,
}) async {
  final String normalizedName = suggestedName.endsWith('.$extension')
      ? suggestedName
      : '$suggestedName.$extension';
  final html.Blob blob = html.Blob(<dynamic>[bytes], mimeType);
  final String objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final bool isPdf = mimeType == 'application/pdf';
  final html.AnchorElement anchor = html.AnchorElement(href: objectUrl)
    ..download = normalizedName
    ..style.position = 'fixed'
    ..style.left = '-10000px'
    ..style.top = '-10000px'
    ..rel = 'noopener';

  if (isPdf) {
    anchor.target = '_blank';
  }

  final html.Element? mountPoint =
      html.document.body ?? html.document.documentElement;
  mountPoint?.append(anchor);
  anchor.dispatchEvent(html.MouseEvent('click'));
  anchor.remove();

  if (isPdf) {
    html.window.open(objectUrl, '_blank');
  }

  Future<void>.delayed(
    const Duration(seconds: 30),
    () => html.Url.revokeObjectUrl(objectUrl),
  );
  return normalizedName;
}
