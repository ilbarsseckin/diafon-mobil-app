import 'package:flutter/material.dart';
import 'api_service.dart';
import 'vehicle_activate_screen.dart';

/// Kullanıcının araçlarını listeleyen ekran (MobilDiafon Auto).
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _vehicles = [];

  static const _red = Color(0xFFE63946);
  static const _navy = Color(0xFF1B2A4A);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.myVehicles();
      setState(() { _vehicles = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _addVehicle() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VehicleActivateScreen()),
    );
    if (added == true) _load();
  }

  // Pasifle / Aktifle
  Future<void> _toggleActive(Map<String, dynamic> v) async {
    final isActive = (v['status']?.toString() ?? 'active') == 'active';
    try {
      await ApiService.setVehicleActive(v['id'].toString(), !isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isActive ? 'Araç pasife alındı' : 'Araç tekrar aktifleştirildi')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> v) async {
    final label = v['label']?.toString() ?? v['plate']?.toString() ?? v['code']?.toString() ?? 'Araç';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aracı Tamamen Sil'),
        content: Text('$label kaydınız kalıcı olarak silinecek. Kartınızı tekrar kullanmak isterseniz yeniden aktive etmeniz gerekir. Emin misiniz?\n\nSadece geçici kapatmak istiyorsanız "Pasifle" seçeneğini kullanın.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteVehicle(v['id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Araç silindi')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  // Arac etiketi / plaka duzenleme
  Future<void> _editInfo(Map<String, dynamic> v) async {
    final labelCtrl = TextEditingController(text: (v['label'] ?? '').toString());
    final plateCtrl = TextEditingController(text: (v['plate'] ?? '').toString());
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> kaydet() async {
              setSheet(() => busy = true);
              try {
                await ApiService.setVehicleInfo(
                  v['id'].toString(),
                  labelCtrl.text.trim(),
                  plateCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Araç bilgileri güncellendi')),
                  );
                  _load();
                }
              } catch (e) {
                setSheet(() => busy = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.edit_outlined, color: _navy),
                      SizedBox(width: 10),
                      Text('Araç Bilgileri',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Aracınızı tanımanız için kullanılır. Plaka, QR okutan kişiye gösterilmez.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: labelCtrl,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Araç Etiketi',
                      hintText: 'Örn: Kırmızı Clio',
                      prefixIcon: const Icon(Icons.label_outline),
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: plateCtrl,
                    maxLength: 20,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Plaka',
                      hintText: 'Örn: 34 ABC 123',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : kaydet,
                      icon: busy
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: Text(busy ? 'Kaydediliyor...' : 'Kaydet'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openMessagePanel(Map<String, dynamic> v) async {
    final current = (v['activeMessage'] ?? '').toString();
    final textCtrl = TextEditingController(text: current);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.chat_bubble_outline, color: _navy),
                  SizedBox(width: 10),
                  Text('Araç Mesajı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text('QR kodunuzu okutan kişi bu mesajı görür.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickChip(textCtrl, '5 dk geliyorum'),
                  _quickChip(textCtrl, '10 dk geliyorum'),
                  _quickChip(textCtrl, '15 dk geliyorum'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                maxLength: 200,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Mesaj',
                  hintText: 'Örn: Aracı yanlış yere park ettiysem arayın',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveMessage(ctx, v['id'].toString(), ''),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Kaldır'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _saveMessage(ctx, v['id'].toString(), textCtrl.text.trim()),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Kaydet'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickChip(TextEditingController ctrl, String text) {
    return ActionChip(
      label: Text(text),
      backgroundColor: _navy.withValues(alpha: 0.06),
      side: BorderSide(color: _navy.withValues(alpha: 0.2)),
      onPressed: () => ctrl.text = text,
    );
  }

  Future<void> _saveMessage(BuildContext sheetCtx, String vehicleId, String message) async {
    Navigator.pop(sheetCtx);
    try {
      await ApiService.setVehicleMessage(vehicleId, message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.isEmpty ? 'Mesaj kaldırıldı' : 'Mesaj kaydedildi')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openUsersPanel(Map<String, dynamic> v) async {
    final vehicleId = v['id'].toString();
    final phoneCtrl = TextEditingController();
    List<dynamic> users = [];
    bool loading = true;
    bool busy = false;
    bool started = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> loadUsers() async {
              try {
                final list = await ApiService.vehicleUsers(vehicleId);
                setSheet(() { users = list; loading = false; });
              } catch (_) {
                setSheet(() { loading = false; });
              }
            }

            if (!started) { started = true; loadUsers(); }

            Future<void> addUser() async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              setSheet(() => busy = true);
              try {
                await ApiService.addVehicleUser(vehicleId, phone);
                phoneCtrl.clear();
                final list = await ApiService.vehicleUsers(vehicleId);
                setSheet(() { users = list; busy = false; });
              } catch (e) {
                setSheet(() => busy = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            }

            Future<void> removeUser(String userId) async {
              setSheet(() => busy = true);
              try {
                await ApiService.removeVehicleUser(vehicleId, userId);
                final list = await ApiService.vehicleUsers(vehicleId);
                setSheet(() { users = list; busy = false; });
              } catch (e) {
                setSheet(() => busy = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.group_outlined, color: _navy),
                      SizedBox(width: 10),
                      Text('Aracı Paylaş', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Eklediğiniz kişiler de aracın zili çalınca bildirim alır. Kişinin uygulamada kayıtlı olması gerekir.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 16),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: _red)),
                    )
                  else if (users.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Henüz ekli kişi yok.', style: TextStyle(color: Colors.grey[500])),
                    )
                  else
                    ...users.map((u) {
                      final m = u as Map<String, dynamic>;
                      final name = m['name']?.toString() ?? '';
                      final phone = m['phone']?.toString() ?? '';
                      final uid = m['userId']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _navy.withValues(alpha: 0.1),
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(phone, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: busy ? null : () => removeUser(uid),
                              icon: const Icon(Icons.remove_circle_outline, color: _red),
                              tooltip: 'Çıkar',
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefon numarası',
                      hintText: 'Kayıtlı numara (örn: 05551234567)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : addUser,
                      icon: busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Kişi Ekle'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araçlarım'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVehicle,
        backgroundColor: _red,
        icon: const Icon(Icons.add),
        label: const Text('Araç Ekle'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _red));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Yenile'),
                style: FilledButton.styleFrom(backgroundColor: _red),
              ),
            ],
          ),
        ),
      );
    }
    if (_vehicles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Henüz aracınız yok',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Kartınızın gizli kodunu girerek aracınızı ekleyin.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _addVehicle,
                icon: const Icon(Icons.add),
                label: const Text('Araç Ekle'),
                style: FilledButton.styleFrom(backgroundColor: _red),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _vehicles.length,
        itemBuilder: (context, i) => _vehicleCard(_vehicles[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> v) {
    final label = v['label']?.toString();
    final plate = v['plate']?.toString();
    final code = v['code']?.toString() ?? '';
    final activeMessage = (v['activeMessage'] ?? '').toString();
    final isActive = (v['status']?.toString() ?? 'active') == 'active';
    final title = (label != null && label.isNotEmpty)
        ? label
        : (plate != null && plate.isNotEmpty ? plate : 'Araç');

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: (isActive ? _red : Colors.grey).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.directions_car, color: isActive ? _red : Colors.grey),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        if (plate != null && plate.isNotEmpty && label != null && label.isNotEmpty)
                          Text(plate, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        Text(code, style: TextStyle(color: Colors.grey[500], fontSize: 12, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  // Durum rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                            size: 14, color: isActive ? Colors.green.shade700 : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(isActive ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                                color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (val) {
                      if (val == 'edit') _editInfo(v);
                      if (val == 'toggle') _toggleActive(v);
                      if (val == 'users') _openUsersPanel(v);
                      if (val == 'delete') _confirmDelete(v);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 20, color: _navy),
                          SizedBox(width: 10),
                          Text('Bilgileri Düzenle'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(children: [
                          Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                              size: 20, color: _navy),
                          const SizedBox(width: 10),
                          Text(isActive ? 'Pasifle' : 'Aktifleştir'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'users',
                        child: Row(children: const [
                          Icon(Icons.group_outlined, size: 20, color: _navy),
                          SizedBox(width: 10),
                          Text('Aracı Paylaş'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 20, color: Color(0xFFE63946)),
                          SizedBox(width: 10),
                          Text('Tamamen Sil', style: TextStyle(color: Color(0xFFE63946))),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
              // Pasif uyarısı
              if (!isActive) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Bu araç pasif. QR okutulunca arama yapılamaz. Menüden "Aktifleştir" ile geri açabilirsiniz.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ),
              ],
              // Aktif mesaj
              if (isActive && activeMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Text('💬 ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(activeMessage,
                            style: const TextStyle(color: Color(0xFF8A6D00), fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
              // Mesaj ayarla (sadece aktifken)
              if (isActive) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMessagePanel(v),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text(activeMessage.isEmpty ? 'Mesaj Ayarla' : 'Mesajı Düzenle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: BorderSide(color: _navy.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}