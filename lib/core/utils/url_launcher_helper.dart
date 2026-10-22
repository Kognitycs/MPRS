import 'package:flutter/material.dart';
import 'package:mprs_android/screens/common/document_webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

Uri? _parseHttpUri(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  final normalized =
      trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.hasScheme) return uri;

  try {
    return Uri.parse(Uri.encodeFull(normalized));
  } catch (_) {
    return null;
  }
}

/// Opens http/https links in browser or system handler (Android 11+ safe).
Future<bool> openHttpUrl(String url) async {
  final uri = _parseHttpUri(url);
  if (uri == null) return false;

  const modes = [
    LaunchMode.externalApplication,
    LaunchMode.platformDefault,
    LaunchMode.inAppBrowserView,
  ];

  for (final mode in modes) {
    try {
      final launched = await launchUrl(uri, mode: mode);
      if (launched) return true;
    } catch (_) {
      // Try next launch mode.
    }
  }

  return false;
}

/// Opens a document URL externally, or in an in-app WebView when no handler exists.
Future<bool> openDocumentUrl(
  BuildContext context,
  String url, {
  String? title,
}) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty || _parseHttpUri(trimmed) == null) return false;

  final openedExternally = await openHttpUrl(trimmed);
  if (openedExternally) return true;

  if (!context.mounted) return false;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (_) => DocumentWebViewScreen(
            url: trimmed,
            title: title?.trim().isNotEmpty == true ? title!.trim() : 'Document',
          ),
    ),
  );
  return true;
}
