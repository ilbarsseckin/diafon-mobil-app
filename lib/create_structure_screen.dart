import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class CreateStructureScreen extends StatefulWidget {
  const CreateStructureScreen({super.key});

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
  String _mode = 'residential'; // 'residential' veya 'business'
  final _businessNameCtrl = TextEditingController();
  String _category = 'diger';
  final Map<String, String> _categories = {
    'saglik': 'Sağlık (dişçi, doktor)',
    'market': 'Market / Bakkal',
    'yeme': 'Yeme-İçme (kafe, restoran)',
    'kuafor': 'Kuaför / Güzellik',
    'ofis': 'Ofis / Büro',
    'diger': 'Diğer',
  };

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
    // İşyeri modu
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
    // Apartman/Site modu - blokları doğrula
    final blocks = <Map<String, dynamic>>[];
    for (final b in _blocks) {
      final count = int.tryParse(b.countCtrl.text.trim()) ?? 0;
      if (count <= 0) {
        _toast('Her blok için geçerli daire sayısı girin');
        return;
      }
      blocks.add({
        'blockName': b.nameCtrl.text.trim().isEmpty ? null : b.nameCtrl.text.trim(),
        'flatCount': count,
      });
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiService.createStructure(
        siteName: _siteNameCtrl.text.trim(),
        latitude: _selected!.latitude,
        longitude: _selected!.longitude,
        blocks: blocks,
      );
      if (mounted) {
        if (res['success'] == true) {
          final count = (res['buildings'] as List?)?.length ?? 0;
          _toast('$count blok başarıyla oluşturuldu');
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _modeButton(String mode, String label) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE63946) : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: active ? Colors.white : Colors.black54, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yapı Kur'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : Column(
        children: [
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _selected!, zoom: 18),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              onTap: (pos) => setState(() => _selected = pos),
              markers: _selected == null ? {} : {
                Marker(markerId: const MarkerId('sel'), position: _selected!),
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mod seçimi
                  Row(
                    children: [
                      _modeButton('residential', '🏢 Apartman / Site'),
                      const SizedBox(width: 8),
                      _modeButton('business', '🏪 İşyeri'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // İŞYERİ FORMU
                  if (_mode == 'business') ...[
                    TextField(
                      controller: _businessNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'İşletme Adı',
                        hintText: 'Örn: Dişçi Ahmet, Market 24',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.store),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: _categories.entries.map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (v) => setState(() => _category = v ?? 'diger'),
                    ),
                    const SizedBox(height: 8),
                    Text('İşyeri tek birimdir. Ziyaretçi sizi konumdan veya QR ile arar. Aynı konumda apartman olsa bile işyeri eklenebilir.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],

                  // APARTMAN / SİTE FORMU
                  if (_mode == 'residential') ...[
                    TextField(
                      controller: _siteNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Site / Bina Adı (opsiyonel)',
                        hintText: 'Örn: Gül Sitesi',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.location_city),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tek bina/apartman için site adını boş bırakıp tek blok ekleyin.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text('Bloklar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_blocks.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => _removeBlock(i),
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addBlock,
                      icon: const Icon(Icons.add_circle, color: Color(0xFFE63946)),
                      label: const Text('Blok Ekle', style: TextStyle(color: Color(0xFFE63946))),
                    ),
                  ],

                  const SizedBox(height: 16),
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
                          : Text(_mode == 'business' ? 'İşyeri Oluştur' : 'Yapıyı Kur', style: const TextStyle(fontSize: 16)),
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