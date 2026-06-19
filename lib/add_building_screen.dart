import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'qr_scan_screen.dart';

class AddBuildingScreen extends StatefulWidget {
  const AddBuildingScreen({super.key});

  @override
  State<AddBuildingScreen> createState() => _AddBuildingScreenState();
}

class _AddBuildingScreenState extends State<AddBuildingScreen> {
  GoogleMapController? _mapController;
  LatLng? _selected;
  bool _loadingLocation = true;
  bool _submitting = false;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getMyLocation();
  }

  Future<void> _getMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _selected = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _selected = const LatLng(41.0082, 28.9784); // İstanbul varsayılan
        _loadingLocation = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selected == null) {
      _toast('Haritadan binanızın konumunu seçin');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Bina adı girin');
      return;
    }
    if (_flatCtrl.text.trim().isEmpty) {
      _toast('Daire no girin');
      return;
    }

    setState(() => _submitting = true);

    // ÖNCE yakındaki binaları kontrol et (çift bina önleme)
    try {
      final nearby = await ApiService.nearbyBuildings(_selected!.latitude, _selected!.longitude);
      if (nearby.isNotEmpty && mounted) {
        setState(() => _submitting = false);
        final choice = await _showNearbyDialog(nearby);
        // choice: null = iptal, 'new' = yeni ekle, aksi = mevcut binaya katıl (buildingName)
        if (choice == null) return; // iptal
        if (choice != 'new') {
          // Mevcut binaya katıl: aslında joinBuilding zaten eşleştirme yapıyor
          // ama kullanıcı onayladı, o binanın adıyla gönderelim
          await _doJoin(buildingNameOverride: choice);
          return;
        }
        // 'new' -> aşağıda yeni ekleme devam eder
      }
    } catch (e) {
      // yakın bina kontrolü başarısızsa, normal akışa devam
    }

    await _doJoin();
  }

  // Yakındaki binaları gösteren dialog
  Future<String?> _showNearbyDialog(List<dynamic> nearby) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakında bina var'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Konumunuza yakın kayıtlı binalar bulundu. Sizinki bunlardan biri mi?'),
            const SizedBox(height: 12),
            ...nearby.map((b) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apartment, color: Color(0xFFE63946)),
              title: Text(b['buildingName']?.toString() ?? 'Bina'),
              subtitle: Text('${b['distance'] ?? '?'} metre uzakta'),
              onTap: () => Navigator.pop(ctx, b['buildingName']?.toString() ?? 'new'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: const Text('Hiçbiri, Yeni Ekle'),
          ),
        ],
      ),
    );
  }

  // Asıl ekleme/katılma işlemi
  Future<void> _doJoin({String? buildingNameOverride}) async {
    setState(() => _submitting = true);
    try {
      final res = await ApiService.joinBuilding(
        buildingName: buildingNameOverride ?? _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: _selected!.latitude,
        longitude: _selected!.longitude,
        flatNo: _flatCtrl.text.trim(),
        floor: _floorCtrl.text.trim().isEmpty ? null : _floorCtrl.text.trim(),
      );
      if (mounted) {
        _toast(res['message'] ?? 'Eklendi');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // QR ile katıl: QR okut -> daire sor -> katıl
  Future<void> _joinByQr() async {
    final qrToken = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (qrToken == null || qrToken.isEmpty) return;

    Map<String, dynamic> info;
    try {
      info = await ApiService.nearbyByQr(qrToken);
    } catch (e) {
      if (mounted) _toast('QR okunamadı');
      return;
    }
    if (info['building'] == null) {
      if (mounted) _toast(info['message']?.toString() ?? 'Geçersiz QR kod');
      return;
    }
    final buildingName = info['building']['buildingName']?.toString() ?? 'Bina';

    if (!mounted) return;
    final flatCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$buildingName binasına katıl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: flatCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daire No *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: floorCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kat', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (flatCtrl.text.trim().isEmpty) {
      if (mounted) _toast('Daire no girin');
      return;
    }

    try {
      final res = await ApiService.joinByQr(
        qrToken: qrToken,
        flatNo: flatCtrl.text.trim(),
        floor: floorCtrl.text.trim().isEmpty ? null : floorCtrl.text.trim(),
      );
      if (mounted) {
        _toast(res['message']?.toString() ?? 'Katıldınız');
        if (res['success'] == true) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _toast(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evimi Ekle'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : Column(
        children: [
          // QR ile katıl (en hızlı yol)
          Container(
            width: double.infinity,
            color: const Color(0xFFE63946).withValues(alpha: 0.06),
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _joinByQr,
              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFE63946)),
              label: const Text('Binadaki QR ile Hızlı Katıl', style: TextStyle(color: Color(0xFFE63946))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE63946)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Harita
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _selected!, zoom: 18),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: (pos) => setState(() => _selected = pos),
                  markers: _selected == null ? {} : {
                    Marker(markerId: const MarkerId('sel'), position: _selected!),
                  },
                ),
                Positioned(
                  bottom: 8, left: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Binanızın tam konumunu haritada işaretleyin (dokunun)',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bina Adı *',
                      hintText: 'Örn: Gül Apartmanı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.apartment),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adres (opsiyonel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _flatCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Daire No *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _floorCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Kat',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Evimi Ekle', style: TextStyle(fontSize: 16)),
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
}