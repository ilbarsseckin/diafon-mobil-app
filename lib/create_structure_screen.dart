import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class CreateStructureScreen extends StatefulWidget {
  /// 'villa' | 'apartment' | 'site' | 'business'
  /// (eski 'residential' de site olarak kabul edilir)
  final String initialMode;
  const CreateStructureScreen({super.key, this.initialMode = 'site'});
  @override
  State<CreateStructureScreen> createState() => _CreateStructureScreenState();
}

class _BlockInput {
  final nameCtrl = TextEditingController();
  final countCtrl = TextEditingController();
}

class _CreateStructureScreenState extends State<CreateStructureScreen> {
  GoogleMapController? _mapController;
  LatLng? _selected;
  bool _loadingLocation = true;
  bool _submitting = false;

  final _siteNameCtrl = TextEditingController();
  final List<_BlockInput> _blocks = [_BlockInput()];
  final _businessNameCtrl = TextEditingController();
  final _ownerFlatCtrl = TextEditingController();
  // Apartman modunda tek daire sayisi kutusu
  final _apartmentCountCtrl = TextEditingController();
  // Villa/Apartman icin bina adi
  final _placeNameCtrl = TextEditingController();
  // Site modunda sahibin oturdugu blok (index)
  int? _ownerBlockIndex;

  // Site: blok adi bossa otomatik A/B/C... uret
  String _blockLabel(int i) {
    final typed = _blocks[i].nameCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    // 0->A, 1->B ... 25->Z, sonra AA benzeri degil, basit tut
    if (i < 26) return '${String.fromCharCode(65 + i)} Blok';
    return '${i + 1}. Blok';
  }

  late String _mode = _normalizeMode(widget.initialMode);

  String _category = 'diger';
  final Map<String, String> _categories = {
    'saglik': 'Sağlık (dişçi, doktor)',
    'market': 'Market / Bakkal',
    'yeme': 'Yeme-İçme (kafe, restoran)',
    'kuafor': 'Kuaför / Güzellik',
    'ofis': 'Ofis / Büro',
    'diger': 'Diğer',
  };

  static String _normalizeMode(String m) {
    if (m == 'residential') return 'site';
    if (m == 'villa' || m == 'apartment' || m == 'site' || m == 'business') {
      return m;
    }
    return 'site';
  }

  bool get _isResidential =>
      _mode == 'villa' || _mode == 'apartment' || _mode == 'site';

  String get _appBarTitle {
    switch (_mode) {
      case 'villa':
        return 'Villa / Müstakil Ev Ekle';
      case 'apartment':
        return 'Apartman Ekle';
      case 'business':
        return 'İşyeri Ekle';
      default:
        return 'Site Kur';
    }
  }

  String get _submitLabel {
    switch (_mode) {
      case 'villa':
        return 'Evi Ekle';
      case 'apartment':
        return 'Apartmanı Ekle';
      case 'business':
        return 'İşyeri Oluştur';
      default:
        return 'Siteyi Kur';
    }
  }

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
        _selected = const LatLng(41.0082, 28.9784);
        _loadingLocation = false;
      });
    }
  }

  void _addBlock() {
    setState(() => _blocks.add(_BlockInput()));
  }

  void _removeBlock(int i) {
    if (_blocks.length <= 1) return;
    setState(() => _blocks.removeAt(i));
  }

  Future<void> _submit() async {
    if (_selected == null) {
      _toast('Haritadan konum seçin');
      return;
    }

    // ---- İŞYERİ ----
    if (_mode == 'business') {
      if (_businessNameCtrl.text.trim().isEmpty) {
        _toast('İşletme adı girin');
        return;
      }
      setState(() => _submitting = true);
      try {
        final res = await ApiService.createBusiness(
          businessName: _businessNameCtrl.text.trim(),
          category: _category,
          latitude: _selected!.latitude,
          longitude: _selected!.longitude,
        );
        if (mounted) {
          if (res['success'] == true) {
            _toast('İşyeri oluşturuldu');
            Navigator.pop(context, true);
          } else {
            _toast(res['message']?.toString() ?? 'Oluşturulamadı');
          }
        }
      } catch (e) {
        if (mounted) _toast(e.toString().replaceAll('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    // ---- KONUT (villa / apartman / site) ----
    // Her mod, backend'e blocks listesi gonderir.
    final blocks = <Map<String, dynamic>>[];
    String siteName = '';
    String ownerFlat = '';
    String ownerBlock = '';

    if (_mode == 'villa') {
      // Villa: tek hane, tek daire. Sahibi orada oturur.
      siteName = _placeNameCtrl.text.trim();
      blocks.add({'blockName': null, 'flatCount': 1});
      ownerFlat = '1';
    } else if (_mode == 'apartment') {
      // Apartman: tek blok, girilen daire sayisi.
      siteName = _placeNameCtrl.text.trim();
      final count = int.tryParse(_apartmentCountCtrl.text.trim()) ?? 0;
      if (count <= 0) {
        _toast('Toplam daire sayısını girin');
        return;
      }
      blocks.add({'blockName': null, 'flatCount': count});
      ownerFlat = _ownerFlatCtrl.text.trim();
    } else {
      // Site: coklu blok.
      siteName = _siteNameCtrl.text.trim();
      for (var i = 0; i < _blocks.length; i++) {
        final b = _blocks[i];
        final count = int.tryParse(b.countCtrl.text.trim()) ?? 0;
        if (count <= 0) {
          _toast('Her blok için geçerli daire sayısı girin');
          return;
        }
        // Blok adi bossa otomatik A/B/C ata (kullanici ugrasmasin)
        blocks.add({
          'blockName': _blockLabel(i),
          'flatCount': count,
        });
      }
      ownerFlat = _ownerFlatCtrl.text.trim();
      // Sahip bir daire girdiyse, sectigi blogun adini gonder
      if (ownerFlat.isNotEmpty && _ownerBlockIndex != null) {
        ownerBlock = _blockLabel(_ownerBlockIndex!);
      }
    }

    // ÖNCE yakındaki binaları kontrol et (çift bina önleme)
    setState(() => _submitting = true);
    try {
      final nearby = await ApiService.nearbyBuildings(
          _selected!.latitude, _selected!.longitude);
      if (nearby.isNotEmpty && mounted) {
        setState(() => _submitting = false);
        final devam = await _showNearbyWarning(nearby);
        if (devam != true) return;
        setState(() => _submitting = true);
      }
    } catch (_) {}

    try {
      final res = await ApiService.createStructure(
        siteName: siteName,
        latitude: _selected!.latitude,
        longitude: _selected!.longitude,
        blocks: blocks,
        ownerFlatNo: ownerFlat,
        ownerBlockName: ownerBlock.isEmpty ? null : ownerBlock,
      );
      if (mounted) {
        if (res['success'] == true) {
          _toast(_mode == 'villa'
              ? 'Eviniz eklendi'
              : (_mode == 'apartment'
              ? 'Apartmanınız eklendi'
              : 'Siteniz kuruldu'));
          Navigator.pop(context, true);
        } else {
          _toast(res['message']?.toString() ?? 'Oluşturulamadı');
        }
      }
    } catch (e) {
      if (mounted) _toast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool?> _showNearbyWarning(List<dynamic> nearby) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakında kayıtlı bina var'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Bu konuma yakın kayıtlı binalar bulundu. Yine de yeni bir yapı mı kurmak istiyorsunuz?'),
            const SizedBox(height: 12),
            ...nearby.map((b) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apartment, color: Color(0xFFE63946)),
              title: Text(b['buildingName']?.toString() ?? 'Bina'),
              subtitle: Text('${b['distance'] ?? '?'} metre uzakta'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yine de Kur'),
          ),
        ],
      ),
    );
  }

  Future<void> _taraVeGoster() async {
    if (_selected == null) {
      _toast('Önce haritadan konum seçin');
      return;
    }
    setState(() => _submitting = true);
    try {
      final nearby = await ApiService.nearbyBuildings(
          _selected!.latitude, _selected!.longitude);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (nearby.isEmpty) {
        _toast('Bu konumda kayıtlı bina bulunamadı. Yeni kurabilirsiniz.');
        return;
      }
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Yakındaki kayıtlı binalar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: nearby
                .map((b) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
              const Icon(Icons.apartment, color: Color(0xFFE63946)),
              title: Text(b['buildingName']?.toString() ?? 'Bina'),
              subtitle: Text('${b['distance'] ?? '?'} metre uzakta'),
            ))
                .toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Tarama başarısız');
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loadingLocation
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : Column(
        children: [
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition:
              CameraPosition(target: _selected!, zoom: 18),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              onTap: (pos) => setState(() => _selected = pos),
              markers: _selected == null
                  ? {}
                  : {
                Marker(
                    markerId: const MarkerId('sel'),
                    position: _selected!),
              },
            ),
          ),
          // Yakındakileri Tara butonu (villada gerek yok, ama zarari yok - herkese acik)
          Container(
            width: double.infinity,
            color: const Color(0xFFE63946).withValues(alpha: 0.06),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _taraVeGoster,
              icon: const Icon(Icons.radar, color: Color(0xFFE63946)),
              label: const Text('Bu Konumu Tara (kayıtlı bina var mı?)',
                  style: TextStyle(color: Color(0xFFE63946))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE63946)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _appBarTitle,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14213D)),
                    ),
                  ),

                  // ---- VİLLA FORMU ----
                  if (_mode == 'villa') ...[
                    TextField(
                      controller: _placeNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ev Adı (opsiyonel)',
                        hintText: 'Örn: Yılmaz Evi',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.house),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoBox(
                      'Müstakil ev / villa tek hanedir. Konumunuzu işaretleyin, '
                          'gerisini biz hallederiz. Ziyaretçileriniz kapıdan veya '
                          'QR ile size ulaşır.',
                    ),
                  ],

                  // ---- APARTMAN FORMU ----
                  if (_mode == 'apartment') ...[
                    TextField(
                      controller: _placeNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Apartman Adı (opsiyonel)',
                        hintText: 'Örn: Gül Apartmanı',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.apartment),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apartmentCountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Toplam Daire Sayısı',
                        hintText: 'Örn: 24',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.meeting_room),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ownerFlatBox(),
                  ],

                  // ---- SİTE FORMU (çok bloklu) ----
                  if (_mode == 'site') ...[
                    TextField(
                      controller: _siteNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Site Adı',
                        hintText: 'Örn: Gül Sitesi',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.location_city),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Her blok için ayrı ad ve daire sayısı girin.',
                      style:
                      TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text('Bloklar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._blocks.asMap().entries.map((entry) {
                      final i = entry.key;
                      final block = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: block.nameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Blok Adı',
                                  hintText: 'A Blok',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: block.countCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Daire',
                                  hintText: '20',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_blocks.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                onPressed: () => _removeBlock(i),
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addBlock,
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFFE63946)),
                      label: const Text('Blok Ekle',
                          style: TextStyle(color: Color(0xFFE63946))),
                    ),
                    const SizedBox(height: 16),
                    _ownerFlatBoxWithBlock(),
                  ],

                  // ---- İŞYERİ FORMU ----
                  if (_mode == 'business') ...[
                    TextField(
                      controller: _businessNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'İşletme Adı',
                        hintText: 'Örn: Dişçi Ahmet, Market 24',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.store),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: _categories.entries
                          .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? 'diger'),
                    ),
                    const SizedBox(height: 8),
                    _infoBox(
                      'İşyeri tek birimdir. Ziyaretçi sizi konumdan veya QR '
                          'ile arar. Aynı konumda apartman olsa bile işyeri '
                          'eklenebilir.',
                    ),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : Text(_submitLabel,
                          style: const TextStyle(fontSize: 16)),
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

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(color: Colors.grey[700], fontSize: 12.5, height: 1.3)),
    );
  }

  // Site modu: once blok sec, sonra daire no gir
  Widget _ownerFlatBoxWithBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.home, color: Color(0xFF2D7DD2), size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text('Bu sitede siz de oturuyor musunuz?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E40AF))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Blok secici
          DropdownButtonFormField<int>(
            value: _ownerBlockIndex,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Hangi blokta oturuyorsunuz?',
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.business, size: 20),
            ),
            hint: const Text('Blok seçin'),
            items: List.generate(_blocks.length, (i) {
              return DropdownMenuItem(
                value: i,
                child: Text(_blockLabel(i)),
              );
            }),
            onChanged: (v) => setState(() => _ownerBlockIndex = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ownerFlatCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Kendi daire numaranız (opsiyonel)',
              hintText: 'Örn: 5',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
              'Blok ve daire girerseniz, o dairenin sakini olarak da eklenirsiniz.',
              style: TextStyle(fontSize: 12, color: Color(0xFF3B6CB3))),
        ],
      ),
    );
  }

  Widget _ownerFlatBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.home, color: Color(0xFF2D7DD2), size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text('Bu binada siz de oturuyor musunuz?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E40AF))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ownerFlatCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Kendi daire numaranız (opsiyonel)',
              hintText: 'Örn: 5',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Doldurursanız bu dairenin sakini olarak da eklenirsiniz.',
              style: TextStyle(fontSize: 12, color: Color(0xFF3B6CB3))),
        ],
      ),
    );
  }
}