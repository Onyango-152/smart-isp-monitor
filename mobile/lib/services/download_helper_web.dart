// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser file-save dialog for [bytes] with [filename].
void downloadBytes(List<int> bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
