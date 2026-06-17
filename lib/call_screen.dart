import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class CallScreen extends StatefulWidget {
  final String peerUserId;
  final String peerName;
  final bool isCaller;
  final String? incomingCallId;

  const CallScreen({
    super.key,
    required this.peerUserId,
    required this.peerName,
    required this.isCaller,
    this.incomingCallId,
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
  String _status = 'Bağlanıyor...';
  bool _connected = false;

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

    _pc = await createPeerConnection(_iceConfig);
    _localStream!.getTracks().forEach((track) {
      _pc!.addTrack(track, _localStream!);
    });

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() { _connected = true; _status = 'Görüşülüyor'; });
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (_callId != null) {
        SocketService.emit('webrtc:ice', {
          'toUserId': widget.peerUserId,
          'callId': _callId,
          'candidate': candidate.toMap(),
        });
      }
    };

    _setupSocketListeners();

    if (widget.isCaller) {
      _startCall();
    } else {
      setState(() { _status = '${widget.peerName} ile bağlanıyor...'; });
      SocketService.emit('call:accept', {'callId': _callId});
    }
  }

  void _setupSocketListeners() {
    SocketService.on('call:accepted', (data) async {
      _callId = data['callId'];
      await _createOffer();
    });

    SocketService.on('webrtc:offer', (data) async {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      SocketService.emit('webrtc:answer', {
        'toUserId': widget.peerUserId,
        'callId': _callId,
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    SocketService.on('webrtc:answer', (data) async {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']),
      );
    });

    SocketService.on('webrtc:ice', (data) async {
      final c = data['candidate'];
      await _pc!.addCandidate(RTCIceCandidate(
        c['candidate'], c['sdpMid'], c['sdpMLineIndex'],
      ));
    });

    SocketService.on('call:rejected', (_) => _endCall(notify: false));
    SocketService.on('call:ended', (_) => _endCall(notify: false));
    SocketService.on('call:unavailable', (data) {
      setState(() { _status = 'Kullanıcı çevrimdışı'; });
      Future.delayed(const Duration(seconds: 2), () => _endCall(notify: false));
    });
  }

  void _startCall() {
    setState(() { _status = '${widget.peerName} aranıyor...'; });
    SocketService.emit('call:start', {'receiverUserId': widget.peerUserId});
  }

  Future<void> _createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    SocketService.emit('webrtc:offer', {
      'toUserId': widget.peerUserId,
      'callId': _callId,
      'sdp': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  void _endCall({bool notify = true}) {
    if (notify && _callId != null) {
      SocketService.emit('call:end', {'callId': _callId});
    }
    _cleanup();
    if (mounted) Navigator.pop(context);
  }

  void _cleanup() {
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
            Positioned(
              top: 16, right: 16,
              width: 110, height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () => _endCall(),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}