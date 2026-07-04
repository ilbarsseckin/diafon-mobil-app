import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bildirim ve izin ayarlari - kritik izinlerin durumu + izin verme.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermItem {
  final String key;
  final String title;
  final String desc;
  final IconData icon;
  final Permission permission;
  final bool critical;
  _PermItem(this.key, this.title, this.desc, this.icon, this.permission, this.critical);
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  final Map<String, PermissionStatus> _status = {};
  bool _loading = true;

  late final List<_PermItem> _items = [
    _PermItem('notif', 'Bildirimler', 'Gelen çağrı ve zil bildirimlerini almak için gereklidir.',
        Icons.notifications_active, Permission.notification, true),
    _PermItem('camera', 'Kamera', 'Görüntülü görüşme sırasında kameranızı kullanmak için.',
        Icons.videocam, Permission.camera, true),
    _PermItem('mic', 'Mikrofon', 'Sesli ve görüntülü görüşme için gereklidir.',
        Icons.mic, Permission.microphone, true),
    _PermItem('location', 'Konum', 'Konumunuza göre bina ve daire bulmak için.',
        Icons.location_on, Permission.locationWhenInUse, false),
    _PermItem('battery', 'Pil Optimizasyonu', 'Uygulamanın kapalıyken bile çağrı alabilmesi için pil kısıtlamasını kaldırın.',
        Icons.battery_charging_full, Permission.ignoreBatteryOptimizations, true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanici sistem ayarlarindan donunce durumu tazele
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final it in _items) {
      _status[it.key] = await it.permission.status;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _request(_PermItem it) async {
    final current = _status[it.key];
    if (current == PermissionStatus.permanentlyDenied) {
      // Kalici reddedilmis -> sistem ayarlarina yonlendir
      await openAppSettings();
      return;
    }
    final res = await it.permission.request();
    setState(() => _status[it.key] = res);
    if (res == PermissionStatus.permanentlyDenied && mounted) {
      // Istek reddedildi + kalici -> ayarlara git
      _showSettingsHint(it.title);
    }
  }

  void _showSettingsHint(String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$title İzni'),
        content: const Text('Bu izni vermek için sistem ayarlarını açmanız gerekiyor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );
  }

  bool get _hasCriticalMissing =>
      _items.any((it) => it.critical && _status[it.key] != PermissionStatus.granted);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Bildirim ve İzinler'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_hasCriticalMissing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bazı önemli izinler eksik. Çağrıları düzgün alabilmek için tümünü vermeniz önerilir.',
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._items.map(_permCard),
              ],
            ),
    );
  }

  Widget _permCard(_PermItem it) {
    final status = _status[it.key] ?? PermissionStatus.denied;
    final granted = status == PermissionStatus.granted;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: (granted ? Colors.green : const Color(0xFFE63946)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(it.icon, color: granted ? Colors.green : const Color(0xFFE63946)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(it.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      if (it.critical) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFFE63946).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Önemli', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFFE63946))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(it.desc, style: TextStyle(color: Colors.grey[600], fontSize: 12.5, height: 1.3)),
                  const SizedBox(height: 10),
                  granted
                      ? Row(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Text('İzin verildi', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                        ])
                      : SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: () => _request(it),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE63946),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              status == PermissionStatus.permanentlyDenied ? 'Ayarları Aç' : 'İzin Ver',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
