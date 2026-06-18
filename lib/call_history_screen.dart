import 'package:flutter/material.dart';
import 'api_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _calls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final calls = await ApiService.callHistory();
      setState(() { _calls = calls; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'ACCEPTED': return 'Görüşüldü';
      case 'ENDED': return 'Görüşüldü';
      case 'REJECTED': return 'Reddedildi';
      case 'MISSED': return 'Cevapsız';
      case 'RINGING': return 'Çalıyor';
      default: return status;
    }
  }

  String _durationText(dynamic duration) {
    if (duration == null) return '';
    final s = duration is int ? duration : int.tryParse(duration.toString()) ?? 0;
    if (s <= 0) return '';
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return ' • $m:$sec';
  }

  String _timeText(dynamic startedAt) {
    if (startedAt == null) return '';
    try {
      final dt = DateTime.parse(startedAt.toString()).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final callDay = DateTime(dt.year, dt.month, dt.day);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      if (callDay == today) return 'Bugün $hh:$mm';
      if (callDay == today.subtract(const Duration(days: 1))) return 'Dün $hh:$mm';
      return '${dt.day}.${dt.month}.${dt.year} $hh:$mm';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çağrı Geçmişi'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
          : _calls.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Henüz çağrı geçmişi yok', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : ListView.separated(
        itemCount: _calls.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = _calls[i];
          final isOutgoing = c['direction'] == 'outgoing';
          final status = c['status']?.toString() ?? '';
          final missed = status == 'MISSED' || status == 'REJECTED';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: missed ? Colors.red.shade50 : Colors.green.shade50,
              child: Icon(
                isOutgoing ? Icons.call_made : Icons.call_received,
                color: missed ? Colors.red : Colors.green,
                size: 20,
              ),
            ),
            title: Text(
              c['otherName']?.toString() ?? 'Bilinmeyen',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${_statusText(status)}${_durationText(c['duration'])}',
              style: TextStyle(
                color: missed ? Colors.red : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            trailing: Text(
              _timeText(c['startedAt']),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}