// ignore: deprecated_member_use
import 'dart:html' as html;

/// Triggers a real browser download of the recipe as a text file - the
/// standard Blob + anchor-click pattern for Flutter web.
Future<bool> downloadRecipeAsFile({required String filename, required String content}) async {
  final blob = html.Blob([content], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
