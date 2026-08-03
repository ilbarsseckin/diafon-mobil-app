import 'package:flutter/material.dart';
import 'api_service.dart';
import 'camera_view_screen.dart';

/// Kapi kamerasi kurulum ekrani (yonetici/bina sahibi kullanir).
/// Marka secilir, IP/kullanici/sifre girilir, RTSP otomatik kurulur.
/// "Diger" secilirse tam RTSP elle girilir.
/// Test Et = backend'e kaydet (go2rtc'ye ekle) + izleme ekranini ac.
class CameraSetupScreen extends StatefulWidget {
  final String buildingId;
  final String buildingName;
  const CameraSetupScreen({
    super.key,
    required this.buildingId,
    this.buildingName = '',
  });

  @override
  State<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends State<CameraSetupScreen> {
  static const _navy = Color(0xFF14213D);
  static const _red = Color(0xFFE63946);

  String _brand = 'hikvision';
  final _ipCtrl = TextEditingController();
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  final _manualCtrl = TextEditingController(); // "Diger" icin tam RTSP
  bool _saving = false;

  // Marka -> RTSP sablonu. {USER} {PASS} {IP} yer tutucular.
  final Map<String, String> _brandLabels = {
    'hikvision': 'Hikvision',
    'dahua': 'Dahua',
    'reolink': 'Reolink',
    'amcrest': 'Amcrest',
    'other': 'Diğer / Bilmiyorum',
  };

  final Map<String, String> _templates = {
    'hikvision': 'rtsp://{USER}:{PASS}@{IP}:554/Streaming/Channels/101',
    'dahua': 'rtsp://{USER}:{PASS}@{IP}:554/cam/realmonitor?channel=1&subtype=0',
    'reolink': 'rtsp://{USER}:{PASS}@{IP}:554/h264Preview_01_main',
    'amcrest': 'rtsp://{USER}:{PASS}@{IP}:554/cam/realmonitor?channel=1&subtype=0',
  };

  bool get _isOther => _brand == 'other';

  String? _buildRtsp() {
    if (_isOther) {
      final m = _manualCtrl.text.trim();
      return m.isEmpty ? null : m;
    }
    final ip = _ipCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (ip.isEmpty) return null;
    final tpl = _templates[_brand]!;
    return tpl
        .replaceAll('{USER}', Uri.encodeComponent(user))
        .replaceAll('{PASS}', Uri.encodeComponent(pass))
        .replaceAll('{IP}', ip);
  }

  Future<void> _testAndSave() async {
    final rtsp = _buildRtsp();
    if (rtsp == null) {
      _toast(_isOther
          ? 'Tam RTSP adresini girin'
          : 'En azından IP adresini girin');
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ApiService.setBuildingCamera(
        buildingId: widget.buildingId,
        rtspUrl: rtsp,
        enabled: true,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (res['success'] == true) {
        // Kaydedildi + go2rtc'ye eklendi -> izleme ekranini ac (test)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraViewScreen(
              buildingId: widget.buildingId,
              title: 'Kamera Testi',
            ),
          ),
        );
        // Izlemeden donunce kullaniciya sor
        if (mounted) _askResult();
      } else {
        _toast(res['message']?.toString() ?? 'Kaydedilemedi');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _askResult() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görüntü geldi mi?'),
        content: const Text(
            'Kapı kamerasının canlı görüntüsünü görebildiniz mi?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Hayir -> bilgileri duzeltmesi icin ekranda kal
            },
            child: const Text('Hayır, düzelteceğim'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () {
              Navigator.pop(ctx); // dialog
              Navigator.pop(context, true); // kurulum ekrani - basarili
            },
            child: const Text('Evet, kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeCamera() async {
    setState(() => _saving = true);
    try {
      await ApiService.setBuildingCamera(
        buildingId: widget.buildingId,
        rtspUrl: null,
        enabled: false,
      );
      if (mounted) {
        setState(() => _saving = false);
        _toast('Kamera kaldırıldı');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Kapı Kamerası'),
        backgroundColor: _red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.buildingName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(widget.buildingName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _navy)),
              ),
            _infoBox(
              'Kapı/giriş kameranızın bilgilerini girin. Ziyaretçi zil çaldığında '
              'kapı kamerası görüntüsünü telefonunuzdan görebilirsiniz.',
            ),
            const SizedBox(height: 16),

            // Marka
            DropdownButtonFormField<String>(
              value: _brand,
              decoration: InputDecoration(
                labelText: 'Kamera Markası',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.videocam),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _brandLabels.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _brand = v ?? 'hikvision'),
            ),
            const SizedBox(height: 14),

            if (!_isOther) ...[
              TextField(
                controller: _ipCtrl,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Kamera IP Adresi',
                  hintText: 'Örn: 192.168.1.45',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.router),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userCtrl,
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  hintText: 'Genelde: admin',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _hintBox(
                'Kullanıcı adı ve şifre, kameranın kutusunda, altındaki '
                'etikette veya kurulum kılavuzunda yazar.',
              ),
            ] else ...[
              TextField(
                controller: _manualCtrl,
                decoration: InputDecoration(
                  labelText: 'Tam RTSP Adresi',
                  hintText: 'rtsp://kullanici:sifre@192.168.1.45:554/...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.link),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _hintBox(
                'Kameranızın RTSP adresini kılavuzundan veya üreticinin '
                'sitesinden öğrenebilirsiniz.',
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _testAndSave,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_circle_outline),
                label: Text(_saving ? 'Bağlanıyor...' : 'Test Et ve Kaydet'),
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : _removeCamera,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.grey),
                label: const Text('Kamerayı Kaldır',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String t) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.35)),
      );

  Widget _hintBox(String t) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 15, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t,
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.grey[600], height: 1.3)),
            ),
          ],
        ),
      );
}
