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
  List<Map<String, dynamic>> _homes = [];
  int _selectedHome = 0;
  _QrType _type = _QrType.building;
  static const String _webBase = 'https://mobildiafon.com/web/ara.html';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final homes = await ApiService.myHomes();
      if (homes.isEmpty) {
        setState(() { _error = 'Önce bir binaya kayıt olmalısınız'; _loading = false; });
        return;
      }
      setState(() {
        _homes = homes.map((h) => Map<String, dynamic>.from(h as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Map<String, dynamic> get _home => _homes[_selectedHome];
  String? get _buildingToken => _home['buildingQrToken']?.toString();
  String? get _flatToken => _home['flatQrToken']?.toString();
  String? get _flatNo => _home['flatNo']?.toString();
  String? get _userId => _home['userId']?.toString();
  bool get _isBusiness => (_home['type']?.toString() == 'business');

  String get _qrData {
    switch (_type) {
      case _QrType.building:
        return '$_webBase?token=$_buildingToken';
      case _QrType.flat:
        // Daire QR: daire token varsa onu, yoksa bina token + flat parametresi
        if (_flatToken != null && _flatToken!.isNotEmpty) {
          return '$_webBase?token=$_flatToken';
        }
        return '$_webBase?token=$_buildingToken&flat=$_flatNo';
      case _QrType.personal:
        return '$_webBase?token=$_buildingToken&user=$_userId';
    }
  }

  String get _qrTitle {
    switch (_type) {
      case _QrType.building:
        return _isBusiness ? 'İşletme QR Kodu' : 'Bina QR Kodu';
      case _QrType.flat:
        return _isBusiness ? 'Birim QR Kodu' : 'Daire $_flatNo QR Kodu';
      case _QrType.personal:
        return 'Kişisel QR Kodum';
    }
  }

  String get _qrDescription {
    switch (_type) {
      case _QrType.building:
        return _isBusiness
            ? 'İşletme girişine asın. Okutan kişi tüm birimleri görüp arayabilir.'
            : 'Bina girişine asın. Okutan kişi tüm sakinleri görüp arayabilir.';
      case _QrType.flat:
        return _isBusiness
            ? 'Biriminize asın. Okutan kişi doğrudan sizi arar.'
            : 'Daire kapınıza asın. Okutan kişi doğrudan dairenizi arar.';
      case _QrType.personal:
        return 'Size özel QR. Okutan kişi doğrudan sizi arar.';
    }
  }

  String _homeLabel(Map<String, dynamic> h) {
    final name = (h['siteName'] ?? h['buildingName'] ?? 'Kayıt').toString();
    final flat = h['flatNo']?.toString();
    return flat != null && flat.isNotEmpty ? '$name • $flat' : name;
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
              : Column(
                  children: [
                    // Kayit secici (birden fazla ev/isletme varsa)
                    if (_homes.length > 1)
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _homes.length,
                          itemBuilder: (_, i) {
                            final sel = i == _selectedHome;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                              child: ChoiceChip(
                                label: Text(_homeLabel(_homes[i])),
                                selected: sel,
                                selectedColor: const Color(0xFFE63946),
                                labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                                backgroundColor: const Color(0xFFF2F4F8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (_) => setState(() { _selectedHome = i; _type = _QrType.building; }),
                              ),
                            );
                          },
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // QR tip secici
                            SegmentedButton<_QrType>(
                              segments: [
                                ButtonSegment(value: _QrType.building, label: Text(_isBusiness ? 'İşletme' : 'Bina'), icon: const Icon(Icons.apartment, size: 18)),
                                ButtonSegment(value: _QrType.flat, label: Text(_isBusiness ? 'Birim' : 'Daire'), icon: const Icon(Icons.door_front_door, size: 18)),
                                const ButtonSegment(value: _QrType.personal, label: Text('Kişisel'), icon: Icon(Icons.person, size: 18)),
                              ],
                              selected: {_type},
                              onSelectionChanged: (s) => setState(() => _type = s.first),
                              style: ButtonStyle(
                                foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Colors.white : const Color(0xFF14213D)),
                                backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? const Color(0xFFE63946) : Colors.white),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(_qrTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE63946))),
                            const SizedBox(height: 16),
                            Screenshot(
                              controller: _screenshotController,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                color: Colors.white,
                                child: Column(
                                  children: [
                                    QrImageView(
                                      data: _qrData,
                                      size: 240,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(_qrTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14213D))),
                                    Text(_homeLabel(_home), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F8),
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
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _sharing ? null : _shareQr,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFE63946),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: _sharing
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.share),
                                label: Text(_sharing ? 'Hazırlanıyor...' : 'QR Kodu Paylaş'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _shareQr() async {
    setState(() => _sharing = true);
    try {
      final image = await _screenshotController.capture();
      if (image == null) throw Exception('Görüntü alınamadı');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mobildiafon_qr.png');
      await file.writeAsBytes(image);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$_qrTitle - MobilDiafon\n$_qrDescription',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paylaşılamadı: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}
