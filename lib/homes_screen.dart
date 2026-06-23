import 'package:flutter/material.dart';
import 'api_service.dart';
import 'call_screen.dart';

class HomesScreen extends StatefulWidget {
  const HomesScreen({super.key});

  @override
  State<HomesScreen> createState() => _HomesScreenState();
}

class _HomesScreenState extends State<HomesScreen> {
  final _pageCtrl = PageController();
  bool _loading = true;
  String? _error;
  List<dynamic> _homes = [];
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final homes = await ApiService.myHomes();
      setState(() { _homes = homes; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  void _call(String userId, String name) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(peerUserId: userId, peerName: name, isCaller: true),
      ),
    );
  }

  String _homeTitle(Map<String, dynamic> h) {
    final site = h['siteName'];
    final block = h['blockName'];
    if (site != null && block != null) return '$site — $block Blok';
    if (block != null) return '${h['buildingName']} — $block';
    return h['buildingName'] ?? 'Evim';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)));
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
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
              ),
            ],
          ),
        ),
      );
    }
    if (_homes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Henüz kayıtlı eviniz yok', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('QR okutarak veya konumdan ev ekleyebilirsiniz.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Nokta göstergesi (birden çok ev varsa)
        if (_homes.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_homes.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE63946) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _homes.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              final h = _homes[i] as Map<String, dynamic>;
              return _buildHome(h);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHome(Map<String, dynamic> h) {
    final residents = (h['residents'] as List?) ?? [];
    final siteFlats = (h['siteFlats'] as List?) ?? [];
    final imageUrl = h['imageUrl'] as String?;

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFE63946),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bina başlığı + resim
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE63946).withValues(alpha: 0.06),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(
                    ApiService.fullPhotoUrl(imageUrl),
                    height: 140, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment, color: Color(0xFFE63946), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_homeTitle(h), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Daire ${h['flatNo'] ?? '-'}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Evim (kendi dairesindeki sakinler)
          if (residents.isNotEmpty) ...[
            _sectionTitle('Evim', Icons.people),
            ...residents.map((r) => _residentTile(r, 'Daire ${h['flatNo']}')),
            const SizedBox(height: 20),
          ],

          // Site/Bina komşuları
          _sectionTitle(h['siteName'] != null ? 'Site Sakinleri' : 'Bina Sakinleri', Icons.holiday_village),
          if (siteFlats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Başka kayıtlı komşu yok', style: TextStyle(color: Colors.grey[500])),
            )
          else
            ...siteFlats.expand((f) {
              final flat = f as Map<String, dynamic>;
              final flatResidents = (flat['residents'] as List?) ?? [];
              final blockLabel = flat['blockName'] != null ? '${flat['blockName']} Blok ' : '';
              return flatResidents.map((r) => _residentTile(r, '${blockLabel}Daire ${flat['flatNo']}'));
            }),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE63946)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFE63946))),
        ],
      ),
    );
  }

  Widget _residentTile(dynamic r, String sub) {
    final res = r as Map<String, dynamic>;
    final isOnline = res['isOnline'] == true;
    final photoUrl = res['photoUrl'] as String?;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.grey.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOnline ? Colors.green.shade50 : Colors.grey.shade200,
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
              ? NetworkImage(ApiService.fullPhotoUrl(photoUrl))
              : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? Icon(Icons.person, color: isOnline ? Colors.green : Colors.grey)
              : null,
        ),
        title: Text(res['name'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        trailing: FilledButton.tonalIcon(
          onPressed: () => _call(res['userId'] ?? '', res['name'] ?? ''),
          icon: const Icon(Icons.call, size: 18),
          label: const Text('Ara'),
        ),
      ),
    );
  }
}
