import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

/// Yönetici: binanın NFC kapı etiketleri.
/// Etiket ekle → sunucu etiket kimliği verir → telefon etikete adresi yazar.
/// Etikete dokunan telefon, binanın onaylı sakini/sahibi ise kapıyı açar.
class NfcTagsScreen extends StatefulWidget {
  final String buildingId;
  final String buildingName;
  const NfcTagsScreen({super.key, required this.buildingId, required this.buildingName});

  @override
  State<NfcTagsScreen> createState() => _NfcTagsScreenState();
}

class _NfcTagsScreenState extends State<NfcTagsScreen> {
  static const _red = Color(0xFFE63946);
  static const _nfc = MethodChannel('mobildiafon/nfc');

  List<dynamic> _tags = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final t = await ApiService.getNfcTags(widget.buildingId);
      if (mounted) setState(() => _tags = t);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? Colors.green : null),
    );
  }

  Future<bool> _nfcHazir() async {
    try {
      final r = Map<String, dynamic>.from(await _nfc.invokeMethod('isAvailable'));
      if (r['supported'] != true) { _snack('Bu telefonda NFC yok'); return false; }
      if (r['enabled'] != true) { _snack('NFC kapalı. Telefon ayarlarından açın.'); return false; }
      return true;
    } catch (_) {
      _snack('NFC yazma bu cihazda desteklenmiyor');
      return false;
    }
  }

  /// Etikete yazma: "telefonu yaklaştırın" penceresi açık kalır, yazınca kapanır.
  Future<bool> _yaz(String url) async {
    if (!await _nfcHazir()) return false;
    if (!mounted) return false;
    final sonuc = _nfc.invokeMethod('writeUri', {'url': url});
    final kapandi = showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc, size: 64, color: _red),
            SizedBox(height: 16),
            Text('Telefonu etikete yaklaştırın',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Etiket yazılana kadar telefonu sabit tutun.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
    // Kullanıcı pencereyi kapatırsa yazmayı iptal et
    var acik = true;
    kapandi.then((_) {
      acik = false;
      _nfc.invokeMethod('cancel').catchError((_) {});
    });
    // Pencere hâlâ açıksa kapat (kullanıcı kapattıysa ekranın kendisini kapatma)
    void pencereyiKapat() {
      if (acik && mounted) Navigator.of(context).pop();
    }
    try {
      await sonuc;
      pencereyiKapat();
      return true;
    } on PlatformException catch (e) {
      pencereyiKapat();
      if (e.code != 'CANCELLED') _snack(e.message ?? 'Etiket yazılamadı');
      return false;
    }
  }

  Future<void> _ekle() async {
    final ctrl = TextEditingController(text: 'Ana giriş');
    final ad = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni NFC etiketi'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Etiket adı', hintText: 'Ana giriş'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Devam'),
          ),
        ],
      ),
    );
    if (ad == null || ad.isEmpty) return;
    if (!await _nfcHazir()) return;
    try {
      final t = await ApiService.createNfcTag(widget.buildingId, ad);
      final ok = await _yaz(t['url'].toString());
      if (ok) {
        _snack('Etiket hazır: $ad', ok: true);
      } else {
        _snack('Etiket kaydedildi ama yazılamadı. Listeden "Yaz" ile tekrar deneyin.');
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    _load();
  }

  Future<void> _sil(Map<String, dynamic> t) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Etiketi kaldır'),
        content: Text('"${t['label']}" etiketi artık kapıyı açmayacak. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (evet != true) return;
    try {
      await ApiService.deleteNfcTag(t['tag'].toString());
      _snack('Etiket kaldırıldı');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Etiketleri · ${widget.buildingName}'),
        backgroundColor: _red,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        onPressed: _ekle,
        icon: const Icon(Icons.nfc),
        label: const Text('Etiket ekle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: Text(
                      'Etikete dokunan telefon, bu binanın onaylı sakini veya yöneticisi ise kapı açılır. '
                      'Kayıtlı olmayan biri dokunursa kapı açılmaz.\n\n'
                      'Etiketi kapının iç tarafına veya sakinlerin ulaşabileceği bir yere yapıştırın.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    )
                  else if (_tags.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Henüz etiket yok. "Etiket ekle" ile başlayın.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._tags.map((x) {
                      final t = Map<String, dynamic>.from(x as Map);
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.nfc, color: _red),
                          title: Text(t['label']?.toString() ?? 'Etiket',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Kimlik: ${t['tag']}', style: const TextStyle(fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  if (await _yaz(t['url'].toString())) _snack('Etiket yazıldı', ok: true);
                                },
                                child: const Text('Yaz'),
                              ),
                              IconButton(
                                tooltip: 'Kaldır',
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _sil(t),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
