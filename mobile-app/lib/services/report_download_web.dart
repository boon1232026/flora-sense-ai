// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> downloadTextReport({
  required String filename,
  required String content,
}) async {
  final blob = html.Blob([content], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
