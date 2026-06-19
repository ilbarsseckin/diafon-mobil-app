import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'add_building_screen.dart';
import 'qr_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _videoEnabled = true;
  bool _loading = true;
  bool _uploadingPhoto = false;
  bool _savingProfile = false;
  String? _photoUrl;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await ApiService.getVideoEnabled();
    final p = await ApiService.getPhotoUrl();
    setState(() { _videoEnabled = v; _photoUrl = p; });
    try {
      final me = await ApiService.getMe();
      _nameCtrl.text = me['name']?.toString() ?? '';
      _emailCtrl.text = me['email']?.toString() ?? '';
      _phone = me['phone']?.toString() ?? '';
      if (me['photoUrl'] != null) _photoUrl = me['photoUrl']?.toString();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggleVideo(bool value) async {
    setState(() => _videoEnabled = value);
    await ApiService.setVideoEnabled(value);
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Ad soyad boş olamaz');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await ApiService.updateProfile(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (mounted) _toast('Profil güncellendi');
    } catch (e) {
      if (mounted) _toast('Güncellenemedi');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );
      if (file == null) return;
      setState(() => _uploadingPhoto = true);
      final bytes = await file.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final url = await ApiService.uploadProfilePhoto(base64Str);
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
      if (mounted && url != null) {
        _toast('Profil fotoğrafı güncellendi');
      }
    } catch (e) {
      setState(() => _uploadingPhoto = false);
      if (mounted) _toast('Fotoğraf yüklenemedi');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          // Profil fotosu
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('Profil', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                          ? NetworkImage(ApiService.fullPhotoUrl(_photoUrl))
                          : null,
                      child: (_photoUrl == null || _photoUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 50, color: Colors.grey)
                          : null,
                    ),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.black45,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _uploadingPhoto ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera, color: Color(0xFFE63946)),
                  label: const Text('Fotoğraf Seç', style: TextStyle(color: Color(0xFFE63946))),
                ),
              ],
            ),
          ),
          // Ad soyad / email / telefon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Ad Soyad',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-posta (opsiyonel)',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Telefon (değiştirilemez)',
                    hintText: _phone,
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingProfile ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE63946),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _savingProfile
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Profili Kaydet'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Görüşme
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  : 'Gelen çağrılarda kameranız kapalı başlar',
            ),
            secondary: Icon(
              _videoEnabled ? Icons.videocam : Icons.videocam_off,
              color: const Color(0xFFE63946),
            ),
          ),
          const Divider(),
          // Binam
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Binam', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.add_home, color: Color(0xFFE63946)),
            title: const Text('Evimi Ekle / Binaya Katıl'),
            subtitle: const Text('Yeni bir binaya kaydol'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddBuildingScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2, color: Color(0xFFE63946)),
            title: const Text('QR Kodlarım'),
            subtitle: const Text('Bina, daire ve kişisel QR kodları'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}