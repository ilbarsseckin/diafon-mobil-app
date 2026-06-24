import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'call_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _buildings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Konum izni + konum al
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _loading = false; _error = 'Konum izni gerekli'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final list = await ApiService.nearbyVisible(pos.latitude, pos.longitude);
      setState(() { _buildings = list; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Konum alınamadı'; });
    }
  }

  IconData _iconFor(Map<String, dynamic> b) {
    if (b['type'] == 'business') {
      switch (b['businessCategory']) {
        case 'saglik': return Icons.local_hospital;
        case 'market': return Icons.shopping_cart;
        case 'yeme': return Icons.restaurant;
        case 'kuafor': return Icons.content_cut;
        case 'ofis': return Icons.business_center;
        default: return Icons.store;
      }
    }
    return Icons.apartment;
  }

  String _subtitle(Map<String, dynamic> b) {
    final dist = b['distance'];
    final distStr = dist != null ? '$dist m' : '';
    if (b['type'] == 'business') {
      return 'İşyeri · $distStr';
    }
    final units = b['flatCount'] ?? 0;
    return '$units daire · $distStr';
  }

  Future<void> _openBuilding(Map<String, dynamic> b) async {
    // QR+Konum modu ise uyar (aramak için QR gerekli)
    if (b['securityMode'] == 'both') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('QR Gerekli'),
          content: Text('${b['buildingName']} aramak için kapıdaki QR kodu okutmanız gerekiyor.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
      return;
    }
    // Konum modu: binanın sakinlerini çek (by-qr token ile) ve göster
    final token = b['qrToken'] as String?;
    if (token == null) return;
    try {
      final data = await ApiService.nearbyByQr(token);
      final residents = (data['residents'] as List?) ?? [];
      if (!mounted) return;
      if (residents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aranabilecek kişi yok')));
        return;
      }
      // İşyeri (tek birim) → direkt ara
      if (b['type'] == 'business' && residents.length == 1) {
        _callResident(residents[0], b);
        return;
      }
      // Apartman → sakin/daire listesi göster
      _showResidents(residents, b);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilgiler alınamadı')));
    }
  }

  void _showResidents(List<dynamic> residents, Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(b['buildingName'] ?? 'Bina',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: residents.length,
                itemBuilder: (_, i) {
                  final r = residents[i] as Map<String, dynamic>;
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(r['name'] ?? 'İsimsiz'),
                    subtitle: Text('Daire ${r['flatNo'] ?? '?'}'),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () { Navigator.pop(ctx); _callResident(r, b); },
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Ara'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callResident(Map<String, dynamic> r, Map<String, dynamic> b) {
    final userId = r['userId'] ?? '';
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peerUserId: userId,
          peerName: r['name'] ?? 'Sakin',
          isCaller: true,
          buildingId: b['id'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yakındakiler'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 56, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Tekrar Dene')),
                    ],
                  ),
                )
              : _buildings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.explore_off, size: 56, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('Yakında görünür bina yok',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Bu konumda konum modunu açmış bina/işyeri bulunamadı.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _buildings.length,
                      itemBuilder: (_, i) {
                        final b = _buildings[i] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: b['type'] == 'business' ? Colors.orange.shade50 : Colors.blue.shade50,
                              child: Icon(_iconFor(b),
                                color: b['type'] == 'business' ? Colors.orange : Colors.blue),
                            ),
                            title: Text(b['buildingName'] ?? 'Bina',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(_subtitle(b)),
                            trailing: b['securityMode'] == 'both'
                                ? const Icon(Icons.qr_code, color: Colors.grey)
                                : const Icon(Icons.chevron_right),
                            onTap: () => _openBuilding(b),
                          ),
                        );
                      },
                    ),
    );
  }
}
