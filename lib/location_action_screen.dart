import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'add_building_screen.dart';
import 'create_structure_screen.dart';

/// Konum seçip "ne yapmak istiyorsun?" sorusunu soran tek temiz giriş ekranı.
/// 3 net akış: Eve katıl (sakin) / Bina kur (yönetici) / İşyeri ekle.
class LocationActionScreen extends StatefulWidget {
  const LocationActionScreen({super.key});

  @override
  State<LocationActionScreen> createState() => _LocationActionScreenState();
}

class _LocationActionScreenState extends State<LocationActionScreen> {
  LatLng? _selected;
  bool _loadingLocation = true;
  bool _scanning = false;
  List<dynamic> _nearby = [];
  bool _scanned = false;

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
      _scan(); // konum gelince otomatik tara
    } catch (e) {
      setState(() {
        _selected = const LatLng(41.0082, 28.9784);
        _loadingLocation = false;
      });
    }
  }

  Future<void> _scan() async {
    if (_selected == null) return;
    setState(() { _scanning = true; });
    try {
      final nearby = await ApiService.nearbyBuildings(_selected!.latitude, _selected!.longitude);
      if (!mounted) return;
      setState(() { _nearby = nearby; _scanned = true; _scanning = false; });
    } catch (e) {
      if (mounted) setState(() { _scanning = false; _scanned = true; });
    }
  }

  // Eve katıl (sakin)
  Future<void> _goJoin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBuildingScreen()),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  // Bina/site kur (yönetici) - apartman modu
  Future<void> _goCreateStructure() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStructureScreen()),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14213D))),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.2)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Konum Ekle'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : Column(
        children: [
          // HARİTA
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _selected!, zoom: 18),
                  onMapCreated: (c) {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: (pos) {
                    setState(() { _selected = pos; _scanned = false; _nearby = []; });
                    _scan();
                  },
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
                      'Konumu haritada işaretleyin (dokunun)',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // TARAMA SONUCU
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE63946))),
                  SizedBox(width: 10),
                  Text('Bu konum taranıyor...'),
                ],
              ),
            )
          else if (_scanned && _nearby.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD8A8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFFE8830C), size: 18),
                      SizedBox(width: 6),
                      Text('Bu konumda kayıtlı bina var', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB35900))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._nearby.take(3).map((b) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• ${b['buildingName'] ?? 'Bina'}  (${b['distance'] ?? '?'} m)',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF7A5200))),
                  )),
                  const SizedBox(height: 4),
                  const Text('Burada oturuyorsanız "Eve Katıl" seçin, yeni bina KURMAYIN.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB35900), fontStyle: FontStyle.italic)),
                ],
              ),
            )
          else if (_scanned && _nearby.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB6E6C8)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: Color(0xFF1FA85C), size: 18),
                    SizedBox(width: 6),
                    Expanded(child: Text('Bu konumda kayıtlı bina yok. Yeni kurabilirsiniz.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF177A43)))),
                  ],
                ),
              ),

          // 3 SEÇENEK
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, left: 4),
                    child: Text('Bu konumda ne yapmak istiyorsunuz?',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF14213D))),
                  ),
                  // Sakin olarak katıl - sadece yakında kayıtlı bina varsa göster
                  if (_nearby.isNotEmpty)
                    _actionCard(
                      icon: Icons.home,
                      color: const Color(0xFF2D7DD2),
                      title: 'Sakinim — Eve Katıl',
                      subtitle: 'Bu binada oturuyorum, daireme bağlanmak istiyorum.',
                      onTap: _goJoin,
                    ),
                  _actionCard(
                    icon: Icons.apartment,
                    color: const Color(0xFFE63946),
                    title: 'Yöneticiyim — Bina / Site Kur',
                    subtitle: 'Apartman veya sitenin yönetimini ben kuruyorum.',
                    onTap: _goCreateStructure,
                  ),
                  _actionCard(
                    icon: Icons.store,
                    color: const Color(0xFFE8830C),
                    title: 'İşyeri Ekle',
                    subtitle: 'Dükkan, ofis veya işletme ekliyorum (apartman olsa bile).',
                    onTap: _goCreateStructure,
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