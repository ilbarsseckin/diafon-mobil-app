import 'package:flutter/material.dart';
import 'add_building_screen.dart';
import 'create_structure_screen.dart';

/// Basit giriş ekranı: harita/tarama yok, sadece niyet seçimi.
/// 1) Sakin Olarak Katıl  -> AddBuildingScreen (kendi adres/konum akışı var)
/// 2) Yeni Ev / Bina Ekle -> CreateStructureScreen (kendi konum akışı var)
/// (+ küçük seçenek: İşyeri Ekle)
class LocationActionScreen extends StatelessWidget {
  const LocationActionScreen({super.key});

  static const _red = Color(0xFFE63946);
  static const _navy = Color(0xFF14213D);
  static const _blue = Color(0xFF2D7DD2);
  static const _orange = Color(0xFFE8830C);

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
        margin: const EdgeInsets.only(bottom: 16),
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
            // Kullanıcı ne yapacağını önceden bilsin
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
            Text('Durumunuza uygun seçeneği seçin, sizi adım adım yönlendirelim.',
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

            // 2 — YENİ EV / BİNA
            _bigCard(
              icon: Icons.add_home_work,
              color: _red,
              title: 'Yeni Ev / Bina Ekle',
              subtitle:
              'Eviniz veya binanız sistemde yok, yönetici olarak siz kuracaksınız.',
              steps: const ['Konumu işaretle', 'Bina bilgilerini gir', 'Daireleri oluştur'],
              onTap: () => _goCreate(context, 'residential'),
            ),

            const SizedBox(height: 4),
            // Üçüncül seçenek — küçük tutuldu
            Center(
              child: TextButton.icon(
                onPressed: () => _goCreate(context, 'business'),
                icon: const Icon(Icons.store, size: 18, color: _orange),
                label: const Text('İşyeri mi ekleyeceksiniz?',
                    style: TextStyle(
                        color: _orange, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}