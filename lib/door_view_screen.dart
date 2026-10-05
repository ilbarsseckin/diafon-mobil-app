import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';
import 'api_service.dart';

/// C — Canlı kapı görüntüsü (sadece izleme, ses yok).
/// Telefon `door:view-start` yollar; monitör camera 0'ı tek yön video ile yayınlar.
/// Bu ekran gelen `webrtc:offer` (callId:'view') için answer üretir ve videoyu gösterir.
class DoorViewScreen extends StatefulWidget {
  final String apartmentId;
  final String title;
  const DoorViewScreen({super.key, required this.apartmentId, this.title = 'Kapı Görüntüsü'});
  @override
  State<DoorViewScreen> createState() => _DoorViewScreenState();
}

class _DoorViewScreenState extends State<DoorViewScreen> {
  final _remote = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  String? _monitorUserId;
  String _status = 'Kapı görüntüsü açılıyor...';
  bool _connected = false;
  bool _closed = false;

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'turn:128.140.127.151:3478', 'username': 'diafonturn', 'credential': 'turnpass2026'},
    ],
  };

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    await _remote.initialize();
    _pc = await createPeerConnection(_iceConfig);

    // Sadece video ALIYORUZ (recvonly). Local track eklemiyoruz.
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remote.srcObject = event.streams[0];
        if (mounted) setState(() { _connected = true; _status = 'Canlı'; });
      }
    };
    _pc!.onIceCandidate = (c) {
      if (_monitorUserId != null) {
        SocketService.emit('webrtc:ice', {
          'toUserId': _monitorUserId, 'callId': 'view', 'candidate': c.toMap(),
        });
      }
    };

    if (!SocketService.isConnected) {
      await SocketService.connect();
      int waited = 0;
      while (!SocketService.isConnected && waited < 5000) {
        await Future.delayed(const Duration(milliseconds: 200)); waited += 200;
      }
    }

    _setupListeners();
    SocketService.emit('door:view-start', {'apartmentId': widget.apartmentId});
  }

  void _setupListeners() {
    SocketService.on('door:view-target', (data) {
      if (data is Map && data['monitorUserId'] != null) {
        _monitorUserId = data['monitorUserId'].toString();
      }
    });

    SocketService.on('door:view-unavailable', (_) {
      if (mounted) setState(() => _status = 'Kapı monitörü çevrimdışı');
      Future.delayed(const Duration(seconds: 2), _close);
    });

    // Monitörden gelen video offer (sadece door-view)
    SocketService.on('webrtc:offer', (data) async {
      if (data is! Map || data['callId'] != 'view' || _pc == null) return;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      SocketService.emit('webrtc:answer', {
        'toUserId': _monitorUserId,
        'callId': 'view',
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    SocketService.on('webrtc:ice', (data) async {
      if (data is! Map || data['callId'] != 'view' || _pc == null) return;
      final c = data['candidate'];
      try {
        await _pc!.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      } catch (_) {}
    });
  }

  Future<void> _openDoor() async {
    try {
      // Kapıyı monitör açar: POST /calls/door-open { apartmentId }
      final res = await ApiService.openDoorViaMonitor(widget.apartmentId);
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Kapı açıldı ✓' : (res['message']?.toString() ?? 'Kapı açılamadı')),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kapı açılamadı'), backgroundColor: Colors.red));
      }
    }
  }

  void _teardown() {
    SocketService.off('door:view-target');
    SocketService.off('door:view-unavailable');
    SocketService.off('webrtc:offer');
    SocketService.off('webrtc:ice');
    try { _pc?.close(); } catch (_) {}
    try { _remote.dispose(); } catch (_) {}
  }

  void _close() {
    if (_closed) return; _closed = true;
    try { SocketService.emit('door:view-stop', {'apartmentId': widget.apartmentId}); } catch (_) {}
    _teardown();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    if (!_closed) {
      _closed = true;
      try { SocketService.emit('door:view-stop', {'apartmentId': widget.apartmentId}); } catch (_) {}
      _teardown();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: _connected
                ? RTCVideoView(_remote, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
                : Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const CircularProgressIndicator(color: Color(0xFFE63946)),
                        const SizedBox(height: 16),
                        Text(_status, style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                  ),
          ),
          Positioned(
            top: 12, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: _openDoor,
                child: Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: Color(0xFF1FA85C), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_open, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 28),
              GestureDetector(
                onTap: _close,
                child: Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
