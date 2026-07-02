import 'package:flutter/material.dart';
import 'api_service.dart';
import 'create_structure_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  bool _loading = true;
  bool _isManager = false;
  List<dynamic> _pending = [];
  List<dynamic> _myBuildings = [];
  String? _uploadingBuildingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.pendingResidents();
      List<dynamic> homes = [];
      try {
        homes = await ApiService.myHomes();
      } catch (_) {}
      setState(() {
        _isManager = data['isManager'] == true;
        _pending = data['pending'] ?? [];
        _myBuildings = homes;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _changeBuildingPhoto(String buildingId) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1000, maxHeight: 1000, imageQuality: 75);
      if (file == null) return;
      setState(() => _uploadingBuildingId = buildingId);
      final bytes = await file.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final res = await ApiService.setBuildingImage(buildingId: buildingId, base64Photo: base64Str);
      if (mounted) {
        if (res['success'] == true) {
          _toast('Bina fotoğrafı güncellendi');
          _load();
        } else {
          _toast(res['message']?.toString() ?? 'Güncellenemedi');
        }
      }
    } catch (e) {
      if (mounted) _toast('Fotoğraf yüklenemedi');
    } finally {
      if (mounted) setState(() => _uploadingBuildingId = null);
    }
  }


  Future<void> _approve(String residentId, String name) async {
    try {
      await ApiService.approveResident(residentId);
      if (mounted) {
        _toast('$name onaylandı');
        _load();
      }
    } catch (e) {
      if (mounted) _toast('Onaylanamadı');
    }
  }

  Future<void> _reject(String residentId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sakini Reddet'),
        content: Text('$name binadan reddedilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.rejectResident(residentId);
      if (mounted) {
        _toast('$name reddedildi');
        _load();
      }
    } catch (e) {
      if (mounted) _toast('Reddedilemedi');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bina Yönetimi'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Yapı Kur',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateStructureScreen()),
              );
              if (result == true) _load();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : !_isManager
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Henüz bir binanın yöneticisi değilsiniz.\n\nYönetici olmak için premium üyelik gereklidir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // BİNA FOTOĞRAFLARI (yönetici)
          if (_myBuildings.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text('Bina Fotoğrafları', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ..._myBuildings.map((h) => _buildingPhotoCard(h as Map<String, dynamic>)),
            const SizedBox(height: 16),
          ],
          // BEKLEYEN SAKİNLER
          if (_pending.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text('Bekleyen katılım isteği yok', style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text('Katılmak isteyen sakinler', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
          ..._pending.map((p) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE63946).withValues(alpha: 0.1),
                    backgroundImage: (p['photoUrl'] != null && p['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(ApiService.fullPhotoUrl(p['photoUrl']))
                        : null,
                    child: (p['photoUrl'] == null || p['photoUrl'].toString().isEmpty)
                        ? const Icon(Icons.person, color: Color(0xFFE63946))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('Daire ${p['flatNo'] ?? '-'}${p['floor'] != null ? ' • Kat ${p['floor']}' : ''}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        Text(p['phone'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    onPressed: () => _approve(p['residentId'], p['name'] ?? ''),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
                    onPressed: () => _reject(p['residentId'], p['name'] ?? ''),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
  Widget _buildingPhotoCard(Map<String, dynamic> h) {
    final buildingId = (h['buildingId'] ?? h['id'])?.toString();
    final imageUrl = h['imageUrl']?.toString();
    final name = (h['siteName'] ?? h['buildingName'] ?? 'Bina').toString();
    final uploading = _uploadingBuildingId == buildingId;
    if (buildingId == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bina fotoğrafı (varsa) veya placeholder
          Stack(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  ApiService.fullPhotoUrl(imageUrl),
                  height: 140, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _photoPlaceholder(),
                )
              else
                _photoPlaceholder(),
              if (uploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
            ],
          ),
          ListTile(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Bina/işyeri fotoğrafı'),
            trailing: TextButton.icon(
              onPressed: uploading ? null : () => _changeBuildingPhoto(buildingId),
              icon: const Icon(Icons.photo_camera, color: Color(0xFFE63946), size: 20),
              label: const Text('Değiştir', style: TextStyle(color: Color(0xFFE63946))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Icon(Icons.apartment, size: 48, color: Colors.grey.shade400),
    );
  }
}