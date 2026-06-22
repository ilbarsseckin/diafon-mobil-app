import 'package:flutter/material.dart';
import '/api_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  static const navy = Color(0xFF1B2A4A);
  static const red = Color(0xFFE63946);

  bool _loading = true;
  String? _error;
  List<dynamic> _notes = [];
  List<dynamic> _apartments = [];
  String? _apartmentId; // gönderim için seçili daire
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.myNotes();
      final apts = (data['apartments'] as List?) ?? [];
      setState(() {
        _notes = (data['notes'] as List?) ?? [];
        _apartments = apts;
        _apartmentId = apts.isNotEmpty ? apts.first['apartmentId'] : null;
        _loading = false;
      });
      // Görülenleri okundu işaretle
      await ApiService.markNotesRead();
    } catch (e) {
      setState(() { _error = 'Notlar yüklenemedi'; _loading = false; });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _apartmentId == null) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.sendNote(_apartmentId!, text);
      if (res['success'] == true) {
        _ctrl.clear();
        await _load();
      } else {
        _showSnack(res['message']?.toString() ?? 'Gönderilemedi');
      }
    } catch (e) {
      _showSnack('Gönderilemedi');
    } finally {
      setState(() => _sending = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'guvenlik': return 'Güvenlik';
      case 'yonetici': return 'Yönetici';
      case 'sakin': return 'Siz';
      default: return role;
    }
  }

  String _timeLabel(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
      final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      if (sameDay) return hm;
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} $hm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Notlar'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _apartments.isEmpty
          ? _emptyNoApartment()
          : Column(
        children: [
          if (_apartments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Text(
                _apartments.first['label']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600, color: navy),
              ),
            ),
          Expanded(
            child: _notes.isEmpty
                ? _emptyNoNotes()
                : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(14),
              itemCount: _notes.length,
              itemBuilder: (_, i) {
                final n = _notes[i];
                final role = n['fromRole']?.toString() ?? '';
                final mine = role == 'sakin';
                return _noteBubble(n, role, mine);
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _noteBubble(dynamic n, String role, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: mine ? null : Border.all(color: const Color(0xFFE6E9F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_roleLabel(role)} · ${_timeLabel(n['createdAt']?.toString())}',
              style: TextStyle(
                fontSize: 11,
                color: mine ? Colors.white70 : const Color(0xFF8A93A5),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              n['text']?.toString() ?? '',
              style: TextStyle(fontSize: 15, color: mine ? Colors.white : const Color(0xFF1A1A2E)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Güvenliğe not yazın...',
                  filled: true,
                  fillColor: const Color(0xFFF1F4F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _sending ? Colors.grey : red,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyNoApartment() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_outlined, size: 48, color: Color(0xFFB0B8C8)),
            SizedBox(height: 12),
            Text('Henüz bir daireye kayıtlı değilsiniz.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5A6478))),
            SizedBox(height: 4),
            Text('Notlar, bir binaya katıldığınızda görünür.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF8A93A5))),
          ],
        ),
      ),
    );
  }

  Widget _emptyNoNotes() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sticky_note_2_outlined, size: 48, color: Color(0xFFB0B8C8)),
            SizedBox(height: 12),
            Text('Henüz not yok.', style: TextStyle(color: Color(0xFF5A6478), fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Güvenlik veya yönetici not bıraktığında burada görünür.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF8A93A5))),
          ],
        ),
      ),
    );
  }
}