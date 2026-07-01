import 'package:flutter/material.dart';
import 'api_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // CDN'deki hazır onboarding gorselleri (içinde başlık + açıklama dahil)
  static const _images = [
    'https://cdn.mobildiafon.com/onboarding/4.webp',
    'https://cdn.mobildiafon.com/onboarding/5.webp',
    'https://cdn.mobildiafon.com/onboarding/6.webp',
  ];

  Future<void> _finish() async {
    await ApiService.setOnboardingSeen();
    widget.onFinish();
  }

  void _next() {
    if (_page < _images.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _images.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Tam ekran kaydırmalı görseller
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _images.length,
            itemBuilder: (_, i) {
              return Image.network(
                _images[i],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE63946)),
                  );
                },
                errorBuilder: (ctx, err, st) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Görsel yüklenemedi', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              );
            },
          ),

          // Geç butonu (sağ üst)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLast ? null : _finish,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Geç', style: TextStyle(color: Color(0xFF14213D), fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),

          // Alt buton (İleri / Başla)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE63946),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                    child: Text(
                      isLast ? 'Başla' : 'İleri',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}