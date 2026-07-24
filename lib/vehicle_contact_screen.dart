import 'package:flutter/material.dart';
import 'api_service.dart';
import 'call_screen.dart';

/// Arac QR okutulunca acilan ekran.
/// Arac sahibine: sesli arama veya zil (bildirim) gonderilir.
class VehicleContactScreen extends StatefulWidget {
  final String code;
  final Map<String, dynamic> data; // lookupVehicle yaniti

  const VehicleContactScreen({
    super.key,
    required this.code,
    required this.data,
  });

  @override
  State<VehicleContactScreen> createState() => _VehicleContactScreenState();
}

class _VehicleContactScreenState extends State<VehicleContactScreen> {
  static const _red = Color(0xFFE63946);
  static const _navy = Color(0xFF14213D);
  static const _orange = Color(0xFFE8830C);

  bool _ringing = false;

  Map<String, dynamic> get _vehicle =>
      Map<String, dynamic>.from(widget.data['vehicle'] ?? {});
  Map<String, dynamic> get _owner =>
      Map<String, dynamic>.from(widget.data['owner'] ?? {});

  String get _aracAdi {
    final label = _vehicle['label']?.toString();
    final plate = _vehicle['plate']?.toString();
    if (label != null && label.isNotEmpty) return label;
    if (plate != null && plate.isNotEmpty) return plate;
    return 'Araç';
  }

  String get _sahipAdi => (_owner['name'] ?? 'Araç sahibi').toString();
  bool get _online => _owner['isOnline'] == true;
  String? get _mesaj {
    final m = widget.data['activeMessage']?.toString();
    return (m == null || m.isEmpty || m == 'null') ? null : m;
  }

  Future<void> _ara() async {
    final userId = _owner['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Araç sahibine ulaşılamıyor')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peerUserId: userId,
          peerName: _aracAdi,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> _zilCal() async {
    setState(() => _ringing = true);
    try {
      await ApiService.ringVehicle(widget.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Araç sahibine bildirim gönderildi'),
        backgroundColor: Color(0xFF2A9D8F),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _ringing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = _owner['photoUrl']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Araç Sahibi'),
        backgroundColor: _red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Arac karti
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      image: (foto != null && foto.isNotEmpty && foto != 'null')
                          ? DecorationImage(
                              image: NetworkImage(ApiService.fullPhotoUrl(foto)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: (foto == null || foto.isEmpty || foto == 'null')
                        ? const Icon(Icons.directions_car, color: _red, size: 34)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(_aracAdi,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: _navy)),
                  const SizedBox(height: 4),
                  Text(_sahipAdi,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _online ? const Color(0xFF2A9D8F) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_online ? 'Çevrimiçi' : 'Çevrimdışı',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _online
                                  ? const Color(0xFF2A9D8F)
                                  : Colors.grey,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),

            // Sahibin biraktigi mesaj
            if (_mesaj != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF5D9B0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined,
                        color: _orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_mesaj!,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF7A4A00))),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 26),

            // Ara
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _ara,
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.phone),
                label: const Text('Ara',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            // Zil cal
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _ringing ? null : _zilCal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _orange,
                  side: const BorderSide(color: Color(0xFFF5D9B0), width: 1.5),
                  backgroundColor: const Color(0xFFFFF4E5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _ringing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _orange))
                    : const Icon(Icons.notifications_active),
                label: Text(_ringing ? 'Gönderiliyor...' : 'Zil Çal',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Telefon numaranız araç sahibine gösterilmez.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
