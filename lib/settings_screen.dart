import 'dart:convert';
import 'package:diafon_mobil_app/permissions_screen.dart';
import 'package:diafon_mobil_app/shelly_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'add_building_screen.dart';
import 'building_overview_screen.dart';
import 'door_management_screen.dart';
import 'location_action_screen.dart';
import 'main.dart';
import 'manager_screen.dart';
import 'onboarding_screen.dart';
import 'qr_screen.dart';
import 'notes_screen.dart';
import 'subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _videoEnabled = true;
  bool _loading = true;
  String _doorbellSound = 'tone1';
  bool _isManager = false;
  bool _invisible = false; // görünmez (hayalet) mod
  bool _dnd = false; // rahatsız etme modu
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
    final ds = await ApiService.getDoorbellSound();
    setState(() { _videoEnabled = v; _photoUrl = p; _doorbellSound = ds; });
    try {
      final me = await ApiService.getMe();
      _nameCtrl.text = me['name']?.toString() ?? '';
      _emailCtrl.text = me['email']?.toString() ?? '';
      _phone = me['phone']?.toString() ?? '';
      if (me['photoUrl'] != null) _photoUrl = me['photoUrl']?.toString();
    } catch (_) {}
    try {
      final subRes = await ApiService.mySubscription();
      _isManager = subRes['isManager'] == true;
    } catch (_) {}
    try {
      final visible = await ApiService.getMyVisibility();
      _invisible = !visible;
    } catch (_) {}
    try {
      _dnd = await ApiService.getDndMode();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggleVideo(bool value) async {
    setState(() => _videoEnabled = value);
    await ApiService.setVideoEnabled(value);
  }
  Future<void> _pickDoorbellSound() async {
    final secilen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Zil Sesi Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...List.generate(5, (i) {
              final tone = 'tone${i + 1}';
              return RadioListTile<String>(
                value: tone,
                groupValue: _doorbellSound,
                activeColor: const Color(0xFFE63946),
                title: Text('Zil Sesi ${i + 1}'),
                onChanged: (v) => Navigator.pop(ctx, v),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (secilen != null) {
      setState(() => _doorbellSound = secilen);
      await ApiService.setDoorbellSound(secilen);
      if (mounted) _toast('Zil sesi kaydedildi');
    }
  }

  Future<void> _toggleInvisible(bool value) async {
    setState(() => _invisible = value);
    try {
      await ApiService.setMyVisibility(!value); // invisible=true → visible=false
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Görünmez moda geçtiniz' : 'Artık görünürsünüz')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _invisible = !value); // hata olursa geri al
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Oturumu Kapat'),
        content: const Text('Oturumunuzu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oturumu Kapat'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ApiService.logout();
    await ApiService.resetOnboarding();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (ctx) => OnboardingScreen(
        onFinish: () {
          Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => const LoginScreen()));
        },
      )),
          (route) => false,
    );
  }


  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Expanded(child: Text('Üyeliğimi Sil', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: const Text(
          'Hesabınızı silmek istediğinize emin misiniz?\n\n'
              'Sakinseniz: Hesabınız ve tüm verileriniz kalıcı olarak silinir.\n\n'
              'Yöneticiyseniz: Binanız ve tüm sakinleri etkileneceği için hesabınız 30 gün sonra silinir. '
              'Bu süre içinde işlemi iptal edebilirsiniz.\n\n'
              'Bu işlem geri alınamaz.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hesabımı Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await ApiService.deleteAccount();
      if (!mounted) return;
      if (res['success'] == true) {
        final immediate = res['immediate'] == true;
        if (immediate) {
          // Hemen silindi -> çıkış yap, login'e dön
          await ApiService.logout();
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          _toast('Hesabınız silindi');
        } else {
          _toast(res['message']?.toString() ?? 'Hesabınız 30 gün sonra silinecek');
        }
      } else {
        _toast(res['message']?.toString() ?? 'İşlem yapılamadı');
      }
    } catch (e) {
      if (mounted) _toast(e.toString().replaceAll('Exception: ', ''));
    }
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
                  controller: TextEditingController(text: _phone),
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Telefon (değiştirilemez)',
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
          SwitchListTile(
            value: _invisible,
            activeColor: const Color(0xFFE63946),
            onChanged: _toggleInvisible,
            title: const Text('Görünmez Ol (Hayalet Mod)'),
            subtitle: Text(
              _invisible
                  ? 'İsim listesinde görünmüyorsunuz, çağrı almazsınız'
                  : 'İsim listesinde görünür, çağrı alırsınız',
            ),
            secondary: Icon(
              _invisible ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFFE63946),
            ),
          ),
          SwitchListTile(
            value: _dnd,
            activeColor: const Color(0xFFE63946),
            onChanged: (v) async {
              setState(() => _dnd = v);
              await ApiService.setDndMode(v);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(v ? 'Rahatsız Etme modu açık' : 'Rahatsız Etme modu kapalı')),
                );
              }
            },
            title: const Text('Rahatsız Etme'),
            subtitle: Text(
              _dnd
                  ? 'Çağrı ve ziller sessiz gelir'
                  : 'Çağrı ve ziller normal ses çıkarır',
            ),
            secondary: Icon(
              _dnd ? Icons.do_not_disturb_on : Icons.do_not_disturb_off,
              color: const Color(0xFFE63946),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active, color: Color(0xFFE63946)),
            title: const Text('Zil Sesi'),
            subtitle: Text('Ziyaretçi zil çaldığında: Zil Sesi ${_doorbellSound.replaceAll('tone', '')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDoorbellSound,
          ),
          const Divider(),
          // Binam
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Binam', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active, color: Color(0xFFE63946)),
            title: const Text('Notlar'),
            subtitle: const Text('Güvenlik ve yönetimden gelen notlar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_home, color: Color(0xFFE63946)),
            title: const Text('Yeni Yer Ekle'),
            subtitle: const Text('Eve katıl, bina/site kur veya işyeri ekle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationActionScreen()),
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
          if (_isManager)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFE63946)),
              title: const Text('Bina Yönetimi'),
              subtitle: const Text('Daireleri ve sakinleri yönet (yönetici)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BuildingOverviewScreen()),
                );
              },
            ),
          if (_isManager)
            ListTile(
              leading: const Icon(Icons.door_front_door, color: Color(0xFFE63946)),
              title: const Text('Akıllı Kapılar'),
              subtitle: const Text('Kapılarınızı görün ve yönetin (yönetici)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoorManagementScreen()),
                );
              },
            ),
          if (_isManager)
            ListTile(
              leading: const Icon(Icons.wifi_tethering, color: Color(0xFFE63946)),
              title: const Text('Yeni Kapı Kur (Shelly)'),
              subtitle: const Text('Cihazı kutudan çıkarın, kurulumu uygulama yapsın'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final eklendi = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ShellySetupScreen()),
                );
                if (eklendi == true && mounted) {
                  _toast('Kapı kuruldu. Evlerim ekranından test edebilirsiniz.');
                }
              },
            ),
          if (_isManager) ...[
            const Divider(),
            // Abonelik
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Abonelik', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Color(0xFFE63946)),
              title: const Text('Aboneliğim'),
              subtitle: const Text('Paket durumu ve ödeme'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.notifications_active, color: Color(0xFFE63946)),
            title: const Text('Bildirim ve İzinler'),
            subtitle: const Text('Çağrı bildirimleri ve uygulama izinleri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PermissionsScreen()),
              );
            },
          ),
          const Divider(),
          // Hesap
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Hesap', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE63946)),
            title: const Text('Oturumu Kapat'),
            subtitle: const Text('Hesabınızdan çıkış yapın'),
            onTap: _logout,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Üyeliğimi Sil', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Hesabımı ve verilerimi kalıcı olarak sil'),
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}