import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DocumentViewerPage extends StatefulWidget {
  final String title;
  final String url;

  const DocumentViewerPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.grey100)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: widget.title,
        centerTitle: true,
        titleColor: AppColors.white,
        backgroundColor: AppColors.videoPlayerBgColor,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
