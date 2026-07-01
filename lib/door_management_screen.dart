import 'package:flutter/material.dart';
import 'api_service.dart';

/// Yönetici: binalarına Tuya/akıllı kapı ekler, listeler, siler.
class DoorManagementScreen extends StatefulWidget {
  const DoorManagementScreen({super.key});

  @override
  State<DoorManagementScreen> createState() => _DoorManagementScreenState();
}

class _DoorManagementScreenState extends State<DoorManagementScreen> {
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

  // Kapı ekleme dialogu
  Future<void> _addDoorDialog(String buildingId, String buildingName) async {
    final nameCtrl = TextEditingController();
    final deviceCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Akıllı Kapı Ekle', style: TextStyle(fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(buildingName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE63946))),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Kapı Adı',
                  hintText: 'Örn: Bina Girişi, Otopark',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deviceCtrl,
                decoration: InputDecoration(
                  labelText: 'Tuya Cihaz ID',
                  hintText: 'Tuya uygulamasından alın',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              Text('Cihaz ID, Tuya/Smart Life uygulamasında cihaz ayarlarında bulunur.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (nameCtrl.text.trim().isEmpty || deviceCtrl.text.trim().isEmpty) {
      _toast('Kapı adı ve cihaz ID gerekli');
      return;
    }
    try {
      final res = await ApiService.addDoor(
        buildingId: buildingId,
        name: nameCtrl.text.trim(),
        deviceId: deviceCtrl.text.trim(),
        adapter: 'tuya',
      );
      if (res['success'] == true) {
        _toast('Kapı eklendi');
        _loadDoors(buildingId);
      } else {
        _toast(res['message']?.toString() ?? 'Eklenemedi');
      }
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
    }
  }

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

  String _buildingName(Map<String, dynamic> h) {
    return (h['buildingName'] ?? h['name'] ?? 'Bina').toString();
  }

  String? _buildingId(Map<String, dynamic> h) {
    return (h['buildingId'] ?? h['id'])?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akıllı Kapılar'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
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
                        'Binalarınıza Tuya uyumlu akıllı kapı ekleyin. Eklenen kapılar, görüntülü görüşmede ve Evlerim ekranında uzaktan açılabilir.',
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
                              leading: const Icon(Icons.apartment, color: Color(0xFFE63946)),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(isOpen ? '${doors.length} kapı' : 'Kapıları görmek için dokunun'),
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
                                  child: Text('Bu binada henüz kapı yok.', style: TextStyle(color: Colors.grey)),
                                )
                              else
                                ...doors.map((d) {
                                  final dm = d as Map<String, dynamic>;
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.meeting_room, color: Color(0xFF2D7DD2)),
                                    title: Text(dm['name']?.toString() ?? 'Kapı'),
                                    subtitle: Text('Tuya · ${dm['deviceId']?.toString() ?? ''}',
                                        style: const TextStyle(fontSize: 11)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteDoor(dm['id'].toString(), bid),
                                    ),
                                  );
                                }),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _addDoorDialog(bid, name),
                                    icon: const Icon(Icons.add, color: Color(0xFFE63946)),
                                    label: const Text('Kapı Ekle', style: TextStyle(color: Color(0xFFE63946))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE63946)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ),
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
