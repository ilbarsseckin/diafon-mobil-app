import 'package:flutter/material.dart';
import 'add_building_screen.dart';
import 'create_structure_screen.dart';
import 'vehicles_screen.dart';

/// Basit giriş ekranı: harita/tarama yok, sadece niyet seçimi.
/// Üstte: Sakin Olarak Katıl + Araç QR
/// Altta: 4 yer tipi (Villa / Apartman / Site / İşyeri) 2x2 grid
class LocationActionScreen extends StatelessWidget {
  const LocationActionScreen({super.key});

  static const _red = Color(0xFFE63946);
  static const _navy = Color(0xFF14213D);
  static const _blue = Color(0xFF2D7DD2);
  static const _orange = Color(0xFFE8830C);
  static const _teal = Color(0xFF2A9D8F);
  static const _green = Color(0xFF2A9D8F);
  static const _purple = Color(0xFF6C63C4);

  Future<void> _goJoin(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBuildingScreen()),
    );
    if (result == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _goCreate(BuildContext context, String mode) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateStructureScreen(initialMode: mode)),
    );
    if (result == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _goVehicles(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VehiclesScreen()),
    );
    if (result == true && context.mounted) Navigator.pop(context, true);
  }

  // Üstteki geniş kartlar (Sakin / Araç)
  Widget _bigCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<String> steps,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _navy)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.25)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(steps.length, (i) {
                return Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${i + 1}. ${steps[i]}',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: color)),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Alttaki 2x2 grid kutuları (yer tipleri)
  Widget _typeBox({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11.5, color: Colors.grey[600], height: 1.2)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Yeni Yer Ekle'),
        backgroundColor: _red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text('Ne yapmak istiyorsunuz?',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 6),
            Text(
                'Durumunuza uygun seçeneği seçin, sizi adım adım yönlendirelim.',
                style: TextStyle(fontSize: 13.5, color: Colors.grey[600])),
            const SizedBox(height: 22),

            // 1 — SAKİN
            _bigCard(
              icon: Icons.home,
              color: _blue,
              title: 'Sakin Olarak Katıl',
              subtitle:
              'Binanız sistemde zaten kayıtlı, siz dairenize bağlanacaksınız.',
              steps: const ['Adresini bul', 'Binanı seç', 'Daire no gönder'],
              onTap: () => _goJoin(context),
            ),

            // 2 — ARAÇ QR
            _bigCard(
              icon: Icons.directions_car,
              color: _teal,
              title: 'Araç QR Ekle',
              subtitle:
              'Aracınıza QR kartı yapıştırın, numaranız görünmeden size ulaşsınlar.',
              steps: const ['Kartı okut', 'Plakanı gir', 'Aktive et'],
              onTap: () => _goVehicles(context),
            ),

            const SizedBox(height: 10),
            const Text('Yeni bir yer mi kuruyorsunuz?',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 4),
            Text('Kurmak istediğiniz yerin türünü seçin.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 14),

            // 2x2 GRID — yer tipleri
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _typeBox(
                  icon: Icons.house,
                  color: _green,
                  title: 'Villa / Ev',
                  subtitle: 'Müstakil ev, tek hane',
                  onTap: () => _goCreate(context, 'villa'),
                ),
                _typeBox(
                  icon: Icons.apartment,
                  color: _red,
                  title: 'Apartman',
                  subtitle: 'Tek bina, birden çok daire',
                  onTap: () => _goCreate(context, 'apartment'),
                ),
                _typeBox(
                  icon: Icons.location_city,
                  color: _purple,
                  title: 'Site',
                  subtitle: 'Birden çok bloklu',
                  onTap: () => _goCreate(context, 'site'),
                ),
                _typeBox(
                  icon: Icons.store,
                  color: _orange,
                  title: 'İşyeri',
                  subtitle: 'Dükkân, ofis, market',
                  onTap: () => _goCreate(context, 'business'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}