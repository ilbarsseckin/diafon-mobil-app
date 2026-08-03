import 'package:flutter/material.dart';
import 'api_service.dart';

/// Yönetici: binalarındaki akıllı kapıları listeler, röle süresini değiştirir, siler.
///
/// NOT: Tuya desteği arayüzden GİZLENDİ (şimdilik kullanılmıyor).
/// Backend tarafı (TuyaAdapter, add-door adapter:'tuya') olduğu gibi duruyor;
/// mevcut Tuya kayıtları çalışmaya devam eder ve listede görünür.
/// Geri açmak için: _TUYA_ENABLED = true yapmak yeterli.
class DoorManagementScreen extends StatefulWidget {
  const DoorManagementScreen({super.key});

  @override
  State<DoorManagementScreen> createState() => _DoorManagementScreenState();
}

class _DoorManagementScreenState extends State<DoorManagementScreen> {
  static const _red = Color(0xFFE63946);

  /// Tuya manuel kapı ekleme arayüzü. Şimdilik kapalı.
  static const bool _tuyaEnabled = false;

  bool _loading = true;
  List<dynamic> _homes = [];
  final Map<String, List<dynamic>> _doorsByBuilding = {};
  String? _openBuildingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final homes = await ApiService.myHomes();
      setState(() => _homes = homes);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadDoors(String buildingId) async {
    try {
      final doors = await ApiService.getDoors(buildingId);
      setState(() => _doorsByBuilding[buildingId] = doors);
    } catch (_) {
      setState(() => _doorsByBuilding[buildingId] = []);
    }
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _sureYazi(double s) => s == s.roundToDouble() ? '${s.toInt()} sn' : '$s sn';

  // ---------- RÖLE SÜRESİ DEĞİŞTİRME (Shelly) ----------
  // Cihaza gitmeye gerek yok: backend MQTT ile Switch.SetConfig gönderiyor.
  Future<void> _changePulseDialog(Map<String, dynamic> door, String buildingId) async {
    final doorId = door['id'].toString();
    final mevcut = double.tryParse(door['pulseSeconds']?.toString() ?? '') ?? 2;

    double secili = mevcut;
    bool ozel = ![1.0, 2.0, 5.0, 8.0].contains(mevcut);
    final ozelCtrl = TextEditingController(text: mevcut.toString());

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Röle Süresi', style: TextStyle(fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(door['name']?.toString() ?? 'Kapı',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _red)),
                const SizedBox(height: 14),
                DropdownButtonFormField<double>(
                  initialValue: ozel ? -1.0 : secili,
                  decoration: InputDecoration(
                    labelText: 'Kapı tipi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('Motor tetikleme (1 sn)')),
                    DropdownMenuItem(value: 2.0, child: Text('Kilit dili / buzzer (2 sn)')),
                    DropdownMenuItem(value: 5.0, child: Text('Manyetik kilit (5 sn)')),
                    DropdownMenuItem(value: 8.0, child: Text('Geniş kapı / bahçe (8 sn)')),
                    DropdownMenuItem(value: -1.0, child: Text('Özel süre gir...')),
                  ],
                  onChanged: (v) => setDialogState(() {
                    if (v == -1.0) {
                      ozel = true;
                    } else {
                      ozel = false;
                      secili = v ?? 2;
                    }
                  }),
                ),
                if (ozel) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: ozelCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Süre (saniye)',
                      hintText: 'ör. 3 veya 0.5',
                      suffixText: 'sn',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Röle bu süre boyunca çekili kalır, sonra kendi bırakır. '
                      'Ayar cihaza kaydedilir; internet kesilse bile röle kendi bırakır. '
                      'Geçerli aralık: 0.5 - 60 saniye.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal', style: TextStyle(color: Colors.grey))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (onay != true) return;

    double sure = secili;
    if (ozel) {
      final v = double.tryParse(ozelCtrl.text.replaceAll(',', '.'));
      if (v == null || v < 0.5 || v > 60) {
        _toast('Süre 0.5 ile 60 saniye arasında olmalı');
        return;
      }
      sure = v;
    }

    _toast('Cihaza gönderiliyor...');
    try {
      final res = await ApiService.setDoorPulse(doorId, sure);
      if (res['success'] == true) {
        _toast('Röle süresi ${_sureYazi(sure)} olarak ayarlandı');
        _loadDoors(buildingId);
      } else {
        _toast(res['message']?.toString() ?? 'Ayarlanamadı');
      }
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ---------- KAPI ADI DEĞİŞTİRME ----------
  Future<void> _deleteDoor(String doorId, String buildingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kapıyı Sil'),
        content: const Text('Bu kapı silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await ApiService.deleteDoor(doorId);
      if (res['success'] == true) {
        _toast('Kapı silindi');
        _loadDoors(buildingId);
      } else {
        _toast(res['message']?.toString() ?? 'Silinemedi');
      }
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
    }
  }

  String _buildingName(Map<String, dynamic> h) =>
      (h['buildingName'] ?? h['name'] ?? 'Bina').toString();

  String? _buildingId(Map<String, dynamic> h) =>
      (h['buildingId'] ?? h['id'])?.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akıllı Kapılar'),
        backgroundColor: _red,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _homes.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Henüz bir binanız yok.\n\nKapı eklemek için önce bir bina/site yönetimi kurmalısınız.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Kayıtlı akıllı kapılarınız. Bu kapılar görüntülü görüşmede ve '
                  'Evlerim ekranında uzaktan açılabilir.\n\n'
                  'Yeni kapı eklemek için: Ayarlar → Yeni Kapı Kur',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          ..._homes.map((h) {
            final hm = h as Map<String, dynamic>;
            final bid = _buildingId(hm);
            if (bid == null) return const SizedBox.shrink();
            final name = _buildingName(hm);
            final isOpen = _openBuildingId == bid;
            final doors = _doorsByBuilding[bid] ?? [];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.apartment, color: _red),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        isOpen ? '${doors.length} kapı' : 'Kapıları görmek için dokunun'),
                    trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
                    onTap: () {
                      setState(() => _openBuildingId = isOpen ? null : bid);
                      if (!isOpen) _loadDoors(bid);
                    },
                  ),
                  if (isOpen) ...[
                    const Divider(height: 1),
                    if (doors.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Bu binada henüz kapı yok.\nAyarlar → Yeni Kapı Kur ile ekleyebilirsiniz.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...doors.map((d) {
                        final dm = d as Map<String, dynamic>;
                        final adapter =
                        (dm['adapter']?.toString() ?? '').toLowerCase();
                        final isShelly = adapter == 'shelly';
                        final sure =
                        double.tryParse(dm['pulseSeconds']?.toString() ?? '');

                        final altYazi = StringBuffer();
                        if (isShelly && sure != null) {
                          altYazi.write('Röle: ${_sureYazi(sure)}');
                        }
                        final devId = dm['deviceId']?.toString() ?? '';
                        if (devId.isNotEmpty) {
                          if (altYazi.isNotEmpty) altYazi.write(' · ');
                          altYazi.write(devId);
                        }

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.meeting_room,
                              color: Color(0xFF2D7DD2)),
                          title: Text(dm['name']?.toString() ?? 'Kapı'),
                          subtitle: altYazi.isEmpty
                              ? null
                              : Text(altYazi.toString(),
                              style: const TextStyle(fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isShelly)
                                IconButton(
                                  tooltip: 'Röle süresi',
                                  icon: const Icon(Icons.timer_outlined,
                                      color: Color(0xFF2D7DD2)),
                                  onPressed: () => _changePulseDialog(dm, bid),
                                ),
                              IconButton(
                                tooltip: 'Sil',
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () =>
                                    _deleteDoor(dm['id'].toString(), bid),
                              ),
                            ],
                          ),
                        );
                      }),
                    // Tuya manuel ekleme - simdilik gizli (_tuyaEnabled)
                    if (_tuyaEnabled)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.add, color: _red),
                            label: const Text('Tuya Kapı Ekle (manuel)',
                                style: TextStyle(color: _red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}