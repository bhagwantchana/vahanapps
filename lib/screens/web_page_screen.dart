import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Minimal in-app browser for site pages (Privacy Policy, Terms, …).
/// Navigation is locked to the page it was opened for so in-page links
/// can't walk the WebView off into the rest of the site.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          // iOS never fires onPageFinished for a failed main-frame load —
          // without this the spinner would float over a blank page forever.
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame != false) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
          // Keep the WebView ON the page it was opened for: the site's
          // in-page links (breadcrumb Home, footer tel:/mailto:) would
          // otherwise walk the WebView out of app-embed mode into the full
          // marketing site — with no web-back to return.
          onNavigationRequest: (request) {
            if (request.url == widget.url) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _retry() {
    setState(() {
      _failed = false;
      _loading = true;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _controller),
          if (_failed)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.cloud_off_rounded,
                      size: 44, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    'Could not load the page',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
