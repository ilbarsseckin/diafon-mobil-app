import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'api_service.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

enum _QrType { building, flat, personal }

class _QrScreenState extends State<QrScreen> {
  final _screenshotController = ScreenshotController();
  bool _sharing = false;
  bool _loading = true;
  String? _error;
  String? _qrToken;
  String? _flatNo;
  String? _userId;
  String? _buildingName;

  _QrType _type = _QrType.building;

  static const String _webBase = 'https://mobildiafon.com/web/ara.html';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await ApiService.myBuildingStatus();
      if (status['registered'] != true || status['building'] == null) {
        setState(() { _error = 'Önce bir binaya kayıt olmalısınız'; _loading = false; });
        return;
      }
      setState(() {
        _qrToken = status['building']['qrToken']?.toString();
        _buildingName = status['building']['buildingName']?.toString();
        _flatNo = status['flatNo']?.toString();
        _userId = status['userId']?.toString();
        _loading = false;
      });
      if (_qrToken == null || _qrToken!.isEmpty) {
        setState(() => _error = 'Bu bina için QR kodu bulunamadı');
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  String get _qrData {
    final base = '$_webBase?token=$_qrToken';
    switch (_type) {
      case _QrType.building:
        return base;
      case _QrType.flat:
        return '$base&flat=$_flatNo';
      case _QrType.personal:
        return '$base&user=$_userId';
    }
  }

  String get _qrTitle {
    switch (_type) {
      case _QrType.building:
        return 'Bina QR Kodu';
      case _QrType.flat:
        return 'Daire $_flatNo QR Kodu';
      case _QrType.personal:
        return 'Kişisel QR Kodum';
    }
  }

  String get _qrDescription {
    switch (_type) {
      case _QrType.building:
        return 'Bina girişine asın. Okutan kişi tüm sakinleri görüp arayabilir.';
      case _QrType.flat:
        return 'Daire kapınıza asın. Okutan kişi doğrudan dairenizi arar.';
      case _QrType.personal:
        return 'Size özel QR. Okutan kişi doğrudan sizi arar.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kodlarım'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SegmentedButton<_QrType>(
              segments: const [
                ButtonSegment(value: _QrType.building, label: Text('Bina'), icon: Icon(Icons.apartment)),
                ButtonSegment(value: _QrType.flat, label: Text('Daire'), icon: Icon(Icons.door_front_door)),
                ButtonSegment(value: _QrType.personal, label: Text('Kişisel'), icon: Icon(Icons.person)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 24),
            Text(_qrTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE63946))),
            const SizedBox(height: 4),
            Text(_buildingName ?? '', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(24),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo (paylaşım görselinde marka görünürlüğü)
                    Image.network(
                      'https://cdn.mobildiafon.com/logo/logo.webp',
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('MobilDiafon',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE63946))),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(_qrTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14213D))),
                    if (_buildingName != null)
                      Text(_buildingName!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE63946).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE63946), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_qrDescription, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sharing ? null : _shareQr,
                icon: _sharing
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.share),
                label: Text(_sharing ? 'Hazırlanıyor...' : 'QR Kodu Paylaş'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'QR kodu WhatsApp, e-posta veya diğer uygulamalarla paylaşabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareQr() async {
    setState(() => _sharing = true);
    try {
      final image = await _screenshotController.capture(pixelRatio: 3.0);
      if (image == null) {
        setState(() => _sharing = false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mobildiafon_qr.png');
      await file.writeAsBytes(image);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '$_qrTitle - MobilDiafon\n$_qrDescription',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşılamadı: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}