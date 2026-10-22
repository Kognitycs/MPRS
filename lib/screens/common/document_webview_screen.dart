import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app viewer when the system has no browser/PDF handler (common on emulators).
class DocumentWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const DocumentWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<DocumentWebViewScreen> createState() => _DocumentWebViewScreenState();
}

class _DocumentWebViewScreenState extends State<DocumentWebViewScreen> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                  _loadFailed = false;
                });
              },
              onPageFinished: (_) {
                if (!mounted) return;
                setState(() => _isLoading = false);
              },
              onWebResourceError: (_) {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                  _loadFailed = true;
                });
              },
            ),
          );

    _loadDocument(widget.url);
  }

  void _loadDocument(String url) {
    final direct = url.trim();
    _controller.loadRequest(Uri.parse(direct));
  }

  void _retryWithGoogleViewer() {
    final encoded = Uri.encodeComponent(widget.url.trim());
    _controller.loadRequest(
      Uri.parse('https://docs.google.com/gview?embedded=true&url=$encoded'),
    );
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.main),
            ),
          if (_loadFailed && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not open this document in the viewer.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retryWithGoogleViewer,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.main,
                      ),
                      child: const Text('Try alternate viewer'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
