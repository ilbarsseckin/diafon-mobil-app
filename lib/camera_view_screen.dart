import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';

/// Kapi kamerasi izleme ekrani (TEK YONLU).
/// Sadece izler - kendi kamera/mikrofonunu GONDERMEZ.
/// Signaling backend proxy uzerinden (telefon -> backend -> go2rtc).
class CameraViewScreen extends StatefulWidget {
  final String buildingId;
  final String title;
  const CameraViewScreen({
    super.key,
    required this.buildingId,
    this.title = 'Kapı Kamerası',
  });

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  String _status = 'Bağlanıyor...';
  bool _connected = false;
  bool _failed = false;

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
    _init();
  }

  Future<void> _init() async {
    await _remoteRenderer.initialize();
    try {
      _pc = await createPeerConnection(_iceConfig);

      // Gelen video track'i ekrana bagla
      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          if (mounted) {
            setState(() {
              _connected = true;
              _status = 'Canlı';
            });
          }
        }
      };

      _pc!.onConnectionState = (state) {
        if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          if (mounted && !_connected) {
            setState(() {
              _failed = true;
              _status = 'Bağlantı kurulamadı';
            });
          }
        }
      };

      // Sadece ALMA yonunde transceiver ekle (video izleyecegiz, gondermeyecegiz)
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
        ),
      );

      // Offer olustur
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      // Offer'i backend proxy'ye gonder, answer al
      final answer = await ApiService.cameraWebrtc(
        buildingId: widget.buildingId,
        offerType: offer.type!,
        offerSdp: offer.sdp!,
      );

      if (answer == null || answer['sdp'] == null) {
        if (mounted) {
          setState(() {
            _failed = true;
            _status = answer?['error']?.toString() ?? 'Kamera yanıt vermedi';
          });
        }
        return;
      }

      // Answer'i uygula
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          answer['sdp'] as String,
          (answer['type'] as String?) ?? 'answer',
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status = 'Hata: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  void dispose() {
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    _pc?.close();
    _pc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Center(
            child: _connected
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_failed)
                        const CircularProgressIndicator(color: Colors.white)
                      else
                        const Icon(Icons.videocam_off,
                            color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      Text(_status,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15)),
                      if (_failed) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _failed = false;
                              _status = 'Bağlanıyor...';
                            });
                            _init();
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Tekrar Dene',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
          ),
          // Canli rozeti
          if (_connected)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 5),
                    Text('CANLI',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
