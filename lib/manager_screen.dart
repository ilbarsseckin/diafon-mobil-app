import 'package:flutter/material.dart';
import 'api_service.dart';
import 'create_structure_screen.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  bool _loading = true;
  bool _isManager = false;
  List<dynamic> _pending = [];
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
      setState(() {
        _isManager = data['isManager'] == true;
        _pending = data['pending'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
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
          : _pending.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text('Bekleyen katılım isteği yok', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
}