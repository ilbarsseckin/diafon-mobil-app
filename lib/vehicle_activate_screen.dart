import 'package:flutter/material.dart';
import 'api_service.dart';
import 'qr_scan_screen.dart';

/// Araç aktivasyon ekranı (FIRST-SCAN).
///
/// Akış: etiketi okut → e-posta gir → bitti. Ayrı aktivasyon kodu YOK.
/// Aracı ilk okutup ekleyen kişi sahiplenir.
///
/// ÖNEMLİ: etiket kutunun içinde kapalı gelir. Guvenlik "önce aktive et,
/// sonra cama yapıştır" akışına dayanır — bu yuzden ekranda ve kılavuzda
/// bu sıra vurgulanır.
class VehicleActivateScreen extends StatefulWidget {
  final String? initialCode;
  const VehicleActivateScreen({super.key, this.initialCode});

  @override
  State<VehicleActivateScreen> createState() => _VehicleActivateScreenState();
}

class _VehicleActivateScreenState extends State<VehicleActivateScreen> {
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) _codeCtrl.text = widget.initialCode!;
  }
  bool _saving = false;
  bool _scanned = false;

  static const _red = Color(0xFFE63946);
  static const _navy = Color(0xFF1B2A4A);

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _labelCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (result == null || result.isEmpty) return;
    String code = result.trim();
    final uri = Uri.tryParse(code);
    if (uri != null) {
      if (uri.queryParameters['code'] != null) {
        code = uri.queryParameters['code']!;
      } else if (uri.pathSegments.isNotEmpty) {
        final son = uri.pathSegments.last;
        if (son.toUpperCase().startsWith('AUTO-')) code = son;
      }
    }
    setState(() {
      _codeCtrl.text = code.toUpperCase();
      _scanned = true;
    });
  }

  bool _epostaGecerli(String e) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  Future<void> _activate() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final email = _emailCtrl.text.trim().toLowerCase();

    if (code.isEmpty) {
      _snack('Önce etiketi okutun veya kodu yazın');
      return;
    }
    if (!_epostaGecerli(email)) {
      _snack('Geçerli bir e-posta adresi girin');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiService.activateVehicle(
        code: code,
        email: email,
        label: _labelCtrl.text.trim(),
        plate: _plateCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['success'] == true) {
        await _showSuccess(res);
        if (mounted) Navigator.pop(context, true);
      } else {
        _snack(res['message']?.toString() ?? 'Aktivasyon başarısız');
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSuccess(Map<String, dynamic> res) async {
    final sub = res['subscription'] as Map<String, dynamic>?;
    final end = sub?['currentPeriodEnd']?.toString();
    String endText = '';
    if (end != null) {
      try {
        final d = DateTime.parse(end).toLocal();
        endText = '${d.day}.${d.month}.${d.year}';
      } catch (_) {}
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Expanded(child: Text('Araç Aktive Edildi')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aracınız hesabınıza bağlandı.'),
            const SizedBox(height: 8),
            if (endText.isNotEmpty)
              Text('Aboneliğiniz $endText tarihine kadar aktif.',
                  style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            const Text(
              'Artık etiketi aracınızın camına yapıştırabilirsiniz.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _adimBasligi(int no, String metin, {bool tamam = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tamam ? Colors.green : _navy,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: tamam
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : Text('$no',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Text(metin, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final girdi = OutlineInputBorder(borderRadius: BorderRadius.circular(12));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Ekle'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.directions_car, color: _navy, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Etiketi okutup e-postanızı girin. Aracınızı ekledikten sonra '
                          'etiketi camınıza yapıştırın.',
                      style: TextStyle(fontSize: 13, color: _navy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---------- 1. ETIKET ----------
            _adimBasligi(1, 'Etiketi okutun', tamam: _scanned),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'AUTO-XXXXXX',
                      prefixIcon: const Icon(Icons.qr_code_2),
                      border: girdi,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _scanQr,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Okut'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---------- 2. E-POSTA ----------
            _adimBasligi(2, 'E-posta adresiniz'),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'ornek@mail.com',
                helperText: 'Numaranız değişirse hesabınıza bu adresle ulaşırsınız',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.mail_outline),
                border: girdi,
              ),
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 8),
            const Text('Araç Bilgileri (isteğe bağlı)',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 12),

            TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(
                labelText: 'Araç Etiketi',
                hintText: 'Örn: Kırmızı Clio',
                prefixIcon: const Icon(Icons.label_outline),
                border: girdi,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Plaka',
                hintText: 'Örn: 34 ABC 123',
                prefixIcon: const Icon(Icons.pin_outlined),
                border: girdi,
              ),
            ),
            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: _saving ? null : _activate,
              icon: _saving
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Aktive ediliyor...' : 'Aracı Aktive Et'),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Önce aracı ekleyin, sonra etiketi camınıza yapıştırın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}