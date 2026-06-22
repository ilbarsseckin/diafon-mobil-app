import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';
import 'api_service.dart';

class CallScreen extends StatefulWidget {
  final String peerUserId;
  final String peerName;
  final bool isCaller;
  final String? incomingCallId;
  final String callType; // 'user' (varsayilan) veya 'security'

  const CallScreen({
    super.key,
    required this.peerUserId,
    required this.peerName,
    required this.isCaller,
    this.incomingCallId,
    this.callType = 'user',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _callId;
  late String _peerId = widget.peerUserId; // guvenlikte accepterId ile guncellenir
  String _status = 'Bağlanıyor...';
  bool _connected = false;
  bool _remoteSet = false; // remote description set edildi mi

  bool _micOn = true;
  bool _camOn = true;
  bool _frontCamera = true;

  Timer? _timer;
  int _seconds = 0;

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:128.140.127.151:3478',
        'username': 'diafonturn',
        'credential': 'turnpass2026',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _callId = widget.incomingCallId;
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _localRenderer.srcObject = _localStream;

    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (e) {
      // bazı cihazlarda desteklenmeyebilir
    }

    // Alıcı: görüntü tercihine bak
    if (!widget.isCaller) {
      final showVideo = await ApiService.getVideoEnabled();
      if (!showVideo) {
        final videoTrack = _localStream?.getVideoTracks().first;
        if (videoTrack != null) {
          videoTrack.enabled = false;
          _camOn = false;
        }
      }
    }

    _pc = await createPeerConnection(_iceConfig);
    _localStream!.getTracks().forEach((track) {
      _pc!.addTrack(track, _localStream!);
    });

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() { _connected = true; _status = 'Görüşülüyor'; });
        _startTimer();
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (_callId != null) {
        SocketService.emit('webrtc:ice', {
          'toUserId': _peerId,
          'callId': _callId,
          'candidate': candidate.toMap(),
        });
      }
    };

    // Socket bağlı değilse bağlan ve bekle (uygulama kapalıyken kabul durumu)
    if (!SocketService.isConnected) {
      await SocketService.connect();
      int waited = 0;
      while (!SocketService.isConnected && waited < 5000) {
        await Future.delayed(const Duration(milliseconds: 200));
        waited += 200;
      }
    }

    _setupSocketListeners();

    if (widget.isCaller) {
      _startCall();
    } else {
      setState(() { _status = '${widget.peerName} ile bağlanıyor...'; });
      SocketService.emit('call:accept', {'callId': _callId});
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _durationText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _setupSocketListeners() {
    SocketService.on('call:ringing', (data) {
      _callId = data['callId'];
    });

    // SADECE ARAYAN: kabul edildi -> offer yap
    SocketService.on('call:accepted', (data) async {
      if (!widget.isCaller) return; // alıcı offer yapmaz
      _callId = data['callId'];
      if (data['accepterId'] != null) _peerId = data['accepterId'];
      await _createOffer();
    });

    // SADECE ALICI: offer geldi -> answer yap
    SocketService.on('webrtc:offer', (data) async {
      if (widget.isCaller) return; // arayan answer yapmaz
      if (_pc == null) return;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
      );
      _remoteSet = true;
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      SocketService.emit('webrtc:answer', {
        'toUserId': _peerId,
        'callId': _callId,
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    // SADECE ARAYAN: answer geldi -> remote set
    SocketService.on('webrtc:answer', (data) async {
      if (!widget.isCaller) return; // alıcı answer almaz
      if (_pc == null) return;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
      );
      _remoteSet = true;
    });

    SocketService.on('webrtc:ice', (data) async {
      if (_pc == null) return;
      final c = data['candidate'];
      try {
        await _pc!.addCandidate(RTCIceCandidate(
          c['candidate'], c['sdpMid'], c['sdpMLineIndex'],
        ));
      } catch (e) {
        // remote henüz set edilmemişse ICE eklenemez, sessizce geç
      }
    });

    SocketService.on('call:rejected', (_) {
      setState(() => _status = 'Çağrı reddedildi');
      Future.delayed(const Duration(seconds: 1), () => _endCall(notify: false));
    });
    SocketService.on('call:ended', (_) => _endCall(notify: false));
    SocketService.on('call:unavailable', (data) {
      setState(() => _status = (data is Map && data['reason'] != null) ? data['reason'] : 'Ulaşılamıyor');
      Future.delayed(const Duration(seconds: 2), () => _endCall(notify: false));
    });
  }

  void _startCall() {
    if (widget.callType == 'security') {
      setState(() { _status = 'Güvenlik aranıyor...'; });
      SocketService.emit('call:start-security', {});
    } else {
      setState(() { _status = '${widget.peerName} aranıyor...'; });
      SocketService.emit('call:start', {'receiverUserId': widget.peerUserId});
    }
  }

  Future<void> _createOffer() async {
    if (_pc == null) return;
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    SocketService.emit('webrtc:offer', {
      'toUserId': _peerId,
      'callId': _callId,
      'sdp': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  void _toggleMic() {
    final audioTrack = _localStream?.getAudioTracks().first;
    if (audioTrack != null) {
      _micOn = !_micOn;
      audioTrack.enabled = _micOn;
      setState(() {});
    }
  }

  void _toggleCam() {
    final videoTrack = _localStream?.getVideoTracks().first;
    if (videoTrack != null) {
      _camOn = !_camOn;
      videoTrack.enabled = _camOn;
      setState(() {});
    }
  }

  void _switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().first;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
      setState(() => _frontCamera = !_frontCamera);
    }
  }

  void _endCall({bool notify = true}) {
    if (notify && _callId != null) {
      SocketService.emit('call:end', {'callId': _callId});
    }
    _cleanup();
    if (mounted) Navigator.pop(context);
  }

  void _cleanup() {
    _timer?.cancel();
    SocketService.off('call:ringing');
    SocketService.off('call:accepted');
    SocketService.off('webrtc:offer');
    SocketService.off('webrtc:answer');
    SocketService.off('webrtc:ice');
    SocketService.off('call:rejected');
    SocketService.off('call:ended');
    SocketService.off('call:unavailable');
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _connected
                  ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  : Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                      const SizedBox(height: 20),
                      Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
            if (_connected)
              Positioned(
                top: 16, left: 0, right: 0,
                child: Column(
                  children: [
                    Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: Text(_durationText, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: _connected ? 70 : 16, right: 16,
              width: 110, height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _camOn
                    ? RTCVideoView(_localRenderer, mirror: _frontCamera, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                    : Container(
                  color: Colors.grey[800],
                  child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54)),
                ),
              ),
            ),
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(icon: _micOn ? Icons.mic : Icons.mic_off, color: _micOn ? Colors.white24 : Colors.red, onTap: _toggleMic),
                  const SizedBox(width: 16),
                  _controlButton(icon: _camOn ? Icons.videocam : Icons.videocam_off, color: _camOn ? Colors.white24 : Colors.red, onTap: _toggleCam),
                  const SizedBox(width: 16),
                  _controlButton(icon: Icons.cameraswitch, color: Colors.white24, onTap: _switchCamera),
                  const SizedBox(width: 16),
                  _controlButton(icon: Icons.call_end, color: Colors.red, onTap: () => _endCall(), big: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({required IconData icon, required Color color, required VoidCallback onTap, bool big = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: big ? 64 : 56,
        height: big ? 64 : 56,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: big ? 32 : 26),
      ),
    );
  }
}