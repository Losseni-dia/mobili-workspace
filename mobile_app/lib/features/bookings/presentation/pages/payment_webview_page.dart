import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PaymentWebViewPage extends StatefulWidget {
  const PaymentWebViewPage({
    super.key,
    required this.paymentUrl,
    required this.onSuccess,
    required this.onCancel,
  });

  final String paymentUrl;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _checkSuccessUrl(url);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _checkSuccessUrl(url);
          },
          onProgress: (progress) {
            setState(() => _progress = progress);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (_isSuccessUrl(url)) {
              Navigator.pop(context);
              widget.onSuccess();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Ignore les erreurs de redirection vers mobili.app
            if (error.url != null && _isSuccessUrl(error.url!)) {
              Navigator.pop(context);
              widget.onSuccess();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _isSuccessUrl(String url) {
    return url.contains('mobili.app/payment/success');
  }

  void _checkSuccessUrl(String url) {
    if (_isSuccessUrl(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.white),
          onPressed: () {
            widget.onCancel();
            Navigator.pop(context);
          },
        ),
        title: Text('Paiement sécurisé',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            )),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded,
                    color: AppColors.mobiliYellow, size: 14),
                const SizedBox(width: 4),
                Text('FedaPay',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    )),
              ],
            ),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  backgroundColor: AppColors.mobiliBlue,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.mobiliYellow),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}