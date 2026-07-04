import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'api_service.dart';

/// Sakin olarak binaya katılma — 3 adımlı akış:
/// 1) Adres ara veya konumunu kullan
/// 2) Haritada/listede binayı seç
/// 3) Daire numaranı gir ve talebi gönder
class AddBuildingScreen extends StatefulWidget {
  const AddBuildingScreen({super.key});

  @override
  State<AddBuildingScreen> createState() => _AddBuildingScreenState();
}

enum _Step { search, pickBuilding, flatNo }

class _AddBuildingScreenState extends State<AddBuildingScreen> {
  static const _red = Color(0xFFE63946);
  static const _navy = Color(0xFF14213D);
  static const _green = Color(0xFF1FA85C);

  _Step _step = _Step.search;

  GoogleMapController? _mapController;
  LatLng? _center;
  bool _scanning = false;
  bool _submitting = false;
  bool _searching = false;
  List<dynamic> _nearby = [];
  Map<String, dynamic>? _selectedBuilding;

  final _flatCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _flatCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ADIM 1 — Konum bulma
  // ---------------------------------------------------------------------------

  Future<void> _useMyLocation() async {
    setState(() => _searching = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _toast('Konum izni verilmedi, adres arayarak deneyin');
        if (mounted) setState(() => _searching = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      await _goToPoint(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      _toast('Konum alınamadı, adres arayarak deneyin');
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      _toast('Lütfen bir adres girin');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _toast('Adres bulunamadı');
        if (mounted) setState(() => _searching = false);
        return;
      }
      final loc = locations.first;
      await _goToPoint(LatLng(loc.latitude, loc.longitude));
    } catch (_) {
      _toast('Adres aranamadı, tekrar deneyin');
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _goToPoint(LatLng target) async {
    setState(() {
      _center = target;
      _selectedBuilding = null;
      _nearby = [];
      _searching = false;
      _scanning = true;
      _step = _Step.pickBuilding;
    });
    // Harita bu adımda yeni oluşturulacağı için animateCamera opsiyonel;
    // yine de mevcutsa taşı.
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    try {
      final nearby =
      await ApiService.nearbyBuildings(target.latitude, target.longitude);
      if (!mounted) return;
      setState(() {
        _nearby = nearby;
        _scanning = false;
        if (nearby.length == 1) {
          _selectedBuilding = nearby.first as Map<String, dynamic>;
          _step = _Step.flatNo;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ADIM 2 — Bina seçimi
  // ---------------------------------------------------------------------------

  void _selectBuilding(Map<String, dynamic> b) {
    setState(() {
      _selectedBuilding = b;
      _step = _Step.flatNo;
    });
  }

  bool _isSameBuilding(Map<String, dynamic>? a, Map<String, dynamic> b) {
    if (a == null) return false;
    // Öncelik id; yoksa isim + koordinat
    if (a['id'] != null && b['id'] != null) return a['id'] == b['id'];
    return a['buildingName'] == b['buildingName'] &&
        a['latitude'] == b['latitude'] &&
        a['longitude'] == b['longitude'];
  }

  Set<Marker> _markers() {
    return _nearby
        .map((b) {
      final bm = b as Map<String, dynamic>;
      final lat = (bm['latitude'] as num?)?.toDouble();
      final lng = (bm['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      final isSel = _isSameBuilding(_selectedBuilding, bm);
      return Marker(
        markerId: MarkerId(bm['id']?.toString() ??
            bm['buildingName']?.toString() ??
            '$lat,$lng'),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: _buildingLabel(bm)),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            isSel ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure),
        onTap: () => setState(() => _selectedBuilding = bm),
      );
    })
        .whereType<Marker>()
        .toSet();
  }

  // ---------------------------------------------------------------------------
  // ADIM 3 — Gönder
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final b = _selectedBuilding;
    if (b == null) {
      _toast('Lütfen katılmak istediğiniz binayı seçin');
      return;
    }
    if (_flatCtrl.text.trim().isEmpty) {
      _toast('Daire numaranızı girin');
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ApiService.joinBuilding(
        buildingName:
        (b['buildingName'] ?? b['siteName'] ?? 'Bina').toString(),
        address: (b['address'] ?? '').toString(),
        latitude: (b['latitude'] as num?)?.toDouble() ?? _center!.latitude,
        longitude: (b['longitude'] as num?)?.toDouble() ?? _center!.longitude,
        flatNo: _flatCtrl.text.trim(),
        floor: null,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: _green),
              SizedBox(width: 10),
              Expanded(
                  child:
                  Text('Talebiniz Alındı', style: TextStyle(fontSize: 18))),
            ],
          ),
          content: Text(
            '${res['message'] ?? 'Katılma talebiniz gönderildi.'}\n\nTalebiniz bina yöneticisi tarafından onaylanacaktır.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------------

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _buildingLabel(Map<String, dynamic> b) {
    final site = b['siteName']?.toString();
    final name = b['buildingName']?.toString() ?? 'Bina';
    if (site != null && site.isNotEmpty) return site;
    return name;
  }

  void _goBack() {
    setState(() {
      switch (_step) {
        case _Step.flatNo:
        // Birden fazla bina varsa listeye, tek bina otomatik seçildiyse aramaya dön
          _step = _nearby.length > 1 ? _Step.pickBuilding : _Step.search;
          if (_step == _Step.search) {
            _nearby = [];
            _selectedBuilding = null;
            _mapController = null;
          }
          break;
        case _Step.pickBuilding:
          _step = _Step.search;
          _nearby = [];
          _selectedBuilding = null;
          _mapController = null;
          break;
        case _Step.search:
          break;
      }
    });
  }

  String get _appBarTitle {
    switch (_step) {
      case _Step.search:
        return 'Sakin Olarak Katıl';
      case _Step.pickBuilding:
        return 'Binanızı Seçin';
      case _Step.flatNo:
        return 'Daire Bilgisi';
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.search,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: Text(_appBarTitle),
          backgroundColor: _red,
          foregroundColor: Colors.white,
          leading: _step != _Step.search
              ? IconButton(
              icon: const Icon(Icons.arrow_back), onPressed: _goBack)
              : null,
        ),
        body: Column(
          children: [
            _stepIndicator(),
            Expanded(
              child: switch (_step) {
                _Step.search => _buildSearchStep(),
                _Step.pickBuilding => _buildPickStep(),
                _Step.flatNo => _buildFlatStep(),
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Adım göstergesi -------------------------------------------------------

  Widget _stepIndicator() {
    final current = _step.index;
    const labels = ['Adres', 'Bina', 'Daire'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = current > i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: done ? _red : Colors.grey.shade300,
              ),
            );
          }
          final idx = i ~/ 2;
          final active = current == idx;
          final done = current > idx;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor:
                active || done ? _red : Colors.grey.shade300,
                child: done
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : Text('${idx + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : Colors.grey[600])),
              ),
              const SizedBox(height: 4),
              Text(labels[idx],
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                      active ? FontWeight.w700 : FontWeight.w400,
                      color: active || done ? _navy : Colors.grey)),
            ],
          );
        }),
      ),
    );
  }

  // --- ADIM 1: Arama ---------------------------------------------------------

  Widget _buildSearchStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.apartment, size: 56, color: _red),
          ),
          const SizedBox(height: 20),
          const Text('Binanızı Bulun',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 6),
          Text('Adresinizi arayın veya konumunuzu kullanın',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 28),
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchAddress(),
            decoration: InputDecoration(
              hintText: 'Adres, mahalle veya semt ara',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () =>
                    setState(() => _searchCtrl.clear()),
              )
                  : null,
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _searching ? null : _searchAddress,
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _searching
                  ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('Adresi Ara',
                  style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('veya',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[500])),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _searching ? null : _useMyLocation,
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.my_location),
              label: const Text('Konumumu Kullan',
                  style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- ADIM 2: Bina seçimi ---------------------------------------------------

  Widget _buildPickStep() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition:
            CameraPosition(target: _center!, zoom: 17),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers(),
          ),
        ),
        Expanded(
          child: _scanning
              ? const Center(
              child: CircularProgressIndicator(color: _red))
              : _nearby.isEmpty
              ? _emptyState()
              : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${_nearby.length} bina bulundu',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _navy)),
              const SizedBox(height: 10),
              ..._nearby.map((b) {
                final bm = b as Map<String, dynamic>;
                final isSel =
                _isSameBuilding(_selectedBuilding, bm);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: isSel
                            ? _red
                            : Colors.grey.shade200,
                        width: isSel ? 2 : 1),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.apartment,
                        color: isSel ? _red : Colors.grey),
                    title: Text(_buildingLabel(bm),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: bm['distance'] != null
                        ? Text('${bm['distance']} m uzakta')
                        : null,
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey),
                    onTap: () => _selectBuilding(bm),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('Bu bölgede kayıtlı bina bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Farklı bir adres arayarak tekrar deneyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _goBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.search),
              label: const Text('Yeni Arama Yap'),
            ),
          ],
        ),
      ),
    );
  }

  // --- ADIM 3: Daire no ------------------------------------------------------

  Widget _buildFlatStep() {
    final b = _selectedBuilding!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _red, width: 2),
            ),
            child: ListTile(
              leading: const Icon(Icons.apartment, color: _red),
              title: Text(_buildingLabel(b),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: b['distance'] != null
                  ? Text('${b['distance']} m uzakta')
                  : null,
              trailing: TextButton(
                onPressed: () =>
                    setState(() => _step = _Step.pickBuilding),
                child: const Text('Değiştir',
                    style: TextStyle(color: _red)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _flatCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Daire Numaranız',
              hintText: 'Örn: 5',
              prefixIcon: const Icon(Icons.meeting_room),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('Katılma Talebi Gönder',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                    'Talebiniz bina yöneticisi tarafından onaylanacaktır.',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[500])),
              ),
            ],
          ),
        ],
      ),
    );
  }
}