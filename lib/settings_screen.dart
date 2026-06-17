import 'package:flutter/material.dart';
import 'api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _videoEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await ApiService.getVideoEnabled();
    setState(() { _videoEnabled = v; _loading = false; });
  }

  Future<void> _toggleVideo(bool value) async {
    setState(() => _videoEnabled = value);
    await ApiService.setVideoEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('Görüşme', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          SwitchListTile(
            value: _videoEnabled,
            activeColor: const Color(0xFFE63946),
            onChanged: _toggleVideo,
            title: const Text('Görüntümü göster'),
            subtitle: Text(
              _videoEnabled
                  ? 'Gelen çağrılarda kameranız açık başlar'
                  : 'Gelen çağrılarda kameranız kapalı başlar (sizi arayan göremez, siz görürsünüz)',
            ),
            secondary: Icon(
              _videoEnabled ? Icons.videocam : Icons.videocam_off,
              color: const Color(0xFFE63946),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Bu ayar sadece gelen çağrılar için geçerlidir. Çağrı sırasında kameranızı her zaman açıp kapatabilirsiniz.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}