import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'api_service.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

enum _QrType { building, flat, personal }

class _QrScreenState extends State<QrScreen> {
  bool _loading = true;
  String? _error;
  String? _qrToken;
  String? _flatNo;
  String? _userId;
  String? _buildingName;

  _QrType _type = _QrType.building;

  static const String _webBase = 'http://128.140.127.151:4000/web/ara.html';

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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
              ),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
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
            const SizedBox(height: 16),
            const Text(
              'QR kodun ekran görüntüsünü alıp yazdırabilir veya paylaşabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}