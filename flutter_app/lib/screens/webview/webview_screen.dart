import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import 'package:go_router/go_router.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final _controller = WebviewController();
  bool _isWebviewInitialized = false;
  bool _isClosing = false; // Prevent multiple pops

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadUrl(widget.url);

      if (!mounted) return;
      setState(() {
        _isWebviewInitialized = true;
      });
    } catch (e) {
      // Handle initialization error
      print('WebView init error: $e');
    }
  }

  Future<void> _extractCookiesAndPop() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      // Execute JS to get cookies and user agent
      final cookiesString = await _controller.executeScript("document.cookie");
      final userAgent = await _controller.executeScript("navigator.userAgent");
      
      // Parse cookies
      final cookies = <String, String>{};
      if (cookiesString != null && cookiesString.toString().isNotEmpty) {
          final parts = cookiesString.toString().split(';');
          for (final part in parts) {
             final keyVal = part.split('=');
             if (keyVal.length >= 2) {
                final key = keyVal[0].trim();
                final val = keyVal.sublist(1).join('=').trim();
                cookies[key] = val;
             }
          }
      }
      
      if (mounted) {
        context.pop({
          'cookies': cookies,
          'userAgent': userAgent.toString(),
        });
      }
    } catch (e) {
      print('Error extraction cookies: $e');
      if (mounted) context.pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Done (Save Cookies)',
            onPressed: _extractCookiesAndPop,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: _isWebviewInitialized
          ? Webview(
              _controller,
              permissionRequested: (url, kind, isUserInitiated) => _onPermissionRequested(url, kind, isUserInitiated),
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _extractCookiesAndPop,
        icon: const Icon(Icons.check),
        label: const Text('I Solved It'),
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.deny;
  }
}
