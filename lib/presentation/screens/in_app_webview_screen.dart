import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InAppWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const InAppWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  bool get _supportsWebView {
    // Chỉ cho phép trên Android & iOS
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();

    if (_supportsWebView) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              setState(() => _progress = progress / 100);
            },
            onWebResourceError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Load lỗi: ${error.description}')),
              );
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu platform không hỗ trợ → show message nhẹ nhàng
    if (!_supportsWebView) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: Center(
          child: Text(
            'In-app viewer chỉ hỗ trợ trên Android / iOS.\n'
            'Hãy chạy app trên mobile để xem trong app.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 1.0
              ? LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2,
                  color: const Color(0xFF5A4FCF),
                  backgroundColor: Colors.grey.shade200,
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
