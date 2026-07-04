import 'package:flutter/material.dart';
import 'api_service.dart';

/// Yonetici: bina > daire > sakin yonetimi (web yonetici paneli mobil karsiligi)
class BuildingOverviewScreen extends StatefulWidget {
  const BuildingOverviewScreen({super.key});

  @override
  State<BuildingOverviewScreen> createState() => _BuildingOverviewScreenState();
}

class _BuildingOverviewScreenState extends State<BuildingOverviewScreen> {
  bool _loading = true;
  bool _isManager = false;
  List<dynamic> _buildings = [];
  String? _error;
  String? _openBuildingId; // acik bina (accordion)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.buildingOverview();
      setState(() {
        _isManager = data['isManager'] == true;
        _buildings = data['buildings'] ?? [];
        if (_buildings.isNotEmpty) _openBuildingId ??= _buildings.first['id']?.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _approve(String residentId, String name) async {
    try {
      await ApiService.approveResident(residentId);
      _toast('$name onaylandı');
      _load();
    } catch (_) {
      _toast('Onaylanamadı');
    }
  }

  Future<void> _remove(String residentId, String name, bool approved) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(approved ? 'Sakini Çıkar' : 'İsteği Reddet'),
        content: Text('$name ${approved ? "binadan çıkarılsın" : "reddedilsin"} mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approved ? 'Çıkar' : 'Reddet'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.rejectResident(residentId);
      _toast('$name ${approved ? "çıkarıldı" : "reddedildi"}');
      _load();
    } catch (_) {
      _toast('İşlem yapılamadı');
    }
  }

  String _buildingLabel(Map<String, dynamic> b) {
    final site = b['siteName']?.toString();
    final block = b['blockName']?.toString();
    final name = b['buildingName']?.toString() ?? 'Bina';
    if (site != null && site.isNotEmpty && block != null && block.isNotEmpty) return '$site · $block';
    if (site != null && site.isNotEmpty) return site;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Bina Yönetimi'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.grey))))
              : !_isManager
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('Henüz bir binanın yöneticisi değilsiniz.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: _buildings.map((b) => _buildingCard(b as Map<String, dynamic>)).toList(),
                    ),
    );
  }

  Widget _buildingCard(Map<String, dynamic> b) {
    final id = b['id']?.toString();
    final isOpen = _openBuildingId == id;
    final flats = (b['flats'] as List?) ?? [];
    final flatCount = b['flatCount'] ?? flats.length;
    final residentCount = b['residentCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFFE63946).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.apartment, color: Color(0xFFE63946)),
            ),
            title: Text(_buildingLabel(b), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('$flatCount daire · $residentCount sakin'),
            trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
            onTap: () => setState(() => _openBuildingId = isOpen ? null : id),
          ),
          if (isOpen) ...[
            const Divider(height: 1),
            if (flats.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Daire yok', style: TextStyle(color: Colors.grey)))
            else
              ...flats.map((f) => _flatTile(f as Map<String, dynamic>)),
          ],
        ],
      ),
    );
  }

  Widget _flatTile(Map<String, dynamic> f) {
    final residents = (f['residents'] as List?) ?? [];
    final flatNo = f['flatNo']?.toString() ?? '-';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.meeting_room, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Daire $flatNo', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 8),
              if (residents.isEmpty)
                Text('(boş)', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
          ...residents.map((r) => _residentRow(r as Map<String, dynamic>)),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _residentRow(Map<String, dynamic> r) {
    final name = r['name']?.toString() ?? '';
    final phone = r['phone']?.toString() ?? '';
    final approved = r['approved'] == true;
    final residentId = r['residentId']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 22),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE63946).withValues(alpha: 0.1),
            backgroundImage: (r['photoUrl'] != null && r['photoUrl'].toString().isNotEmpty)
                ? NetworkImage(ApiService.fullPhotoUrl(r['photoUrl']))
                : null,
            child: (r['photoUrl'] == null || r['photoUrl'].toString().isEmpty)
                ? const Icon(Icons.person, size: 18, color: Color(0xFFE63946))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: approved ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        approved ? 'Onaylı' : 'Bekliyor',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: approved ? Colors.green.shade700 : Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
                Text(phone, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          if (!approved)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Onayla',
              onPressed: () => _approve(residentId, name),
            ),
          IconButton(
            icon: Icon(approved ? Icons.person_remove : Icons.cancel, color: Colors.red),
            tooltip: approved ? 'Çıkar' : 'Reddet',
            onPressed: () => _remove(residentId, name, approved),
          ),
        ],
      ),
    );
  }
}
