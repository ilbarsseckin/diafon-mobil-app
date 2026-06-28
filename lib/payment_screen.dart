import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_service.dart';

class PaymentScreen extends StatefulWidget {
  final String subscriptionId;
  final String period;

  const PaymentScreen({
    super.key,
    required this.subscriptionId,
    required this.period,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _error;
  bool _loading = true;
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  Future<void> _initPayment() async {
    try {
      final data = await ApiService.initializePayment(
        subscriptionId: widget.subscriptionId,
        period: widget.period,
      );

      // iyzico HTML form içeriği
      final htmlContent = data['checkoutFormContent'] as String?;
      // veya direkt URL döndüyse
      final url = data['url'] as String?;

      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (req) {
            final url = req.url;
            debugPrint('WebView navigasyon: $url');
            if (url.contains('odeme-sonuc')) {
              final basarili = url.contains('durum=basarili');
              Navigator.of(context).pop(basarili);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) => debugPrint('Sayfa basladi: $url'),
          onPageFinished: (url) => debugPrint('Sayfa bitti: $url'),
          onWebResourceError: (err) => debugPrint('WebView hata: ${err.description}'),

        ));

      if (htmlContent != null && htmlContent.isNotEmpty) {
        // HTML içeriği direkt yükle
        await ctrl.loadHtmlString(htmlContent, baseUrl: 'https://sandbox-api.iyzipay.com');
      } else if (url != null && url.isNotEmpty) {
        await ctrl.loadRequest(Uri.parse(url));
      } else {
        throw Exception('Ödeme formu alınamadı');
      }

      setState(() {
        _webController = ctrl;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödeme'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _initPayment();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                ),
                child: const Text('Tekrar Dene', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      )
          : WebViewWidget(controller: _webController!),
    );
  }
}