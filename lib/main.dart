import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'add_building_screen.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'call_screen.dart';
import 'settings_screen.dart';
import 'push_service.dart';
import 'callkit_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'dart:async';
// Arka planda/kapalıyken gelen FCM mesajını yakalar
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] == 'incoming_call') {
    await CallKitService.showIncomingCall(
      callId: data['callId'] ?? '',
      callerName: data['callerName'] ?? 'Bilinmeyen',
      callerUserId: data['callerUserId'] ?? '',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (e) {
    // Firebase başlatılamazsa uygulama yine çalışsın
  }
  runApp(const DiafonApp());
}

class DiafonApp extends StatelessWidget {
  const DiafonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diafon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE63946),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await ApiService.getToken();
    final name = await ApiService.getUserName();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    // Giriş var -> binaya kayıtlı mı?
    bool registered = true;
    try {
      final status = await ApiService.myBuildingStatus();
      // ignore: avoid_print
      print('BINA DURUMU: $status');
      registered = status['registered'] == true;
    } catch (e) {
      // ignore: avoid_print
      print('BINA DURUMU HATA: $e');
    }
    if (!mounted) return;
    if (registered) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userName: name ?? '')),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userName: name ?? '', autoAddBuilding: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.doorbell, size: 72, color: Color(0xFFE63946)),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Color(0xFFE63946)),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      final phone = _phoneCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) {
        try {
          await ApiService.register(name, phone);
        } catch (e) {
          await ApiService.login(phone);
        }
      } else {
        await ApiService.login(phone);
      }
      setState(() { _otpSent = true; });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.verify(_phoneCtrl.text.trim(), _codeCtrl.text.trim());
      // Binaya kayıtlı mı kontrol et
      bool registered = true;
      try {
        final status = await ApiService.myBuildingStatus();
        registered = status['registered'] == true;
      } catch (_) {}
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: data['user']['name'],
              autoAddBuilding: !registered,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.doorbell, size: 64, color: Color(0xFFE63946)),
                const SizedBox(height: 16),
                const Text('Diafon',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _otpSent ? 'Telefonunuza gelen kodu girin' : 'Telefon numaranızla giriş yapın',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                if (!_otpSent) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad (yeni üyelik için)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (05xxxxxxxxx)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(
                      labelText: 'Doğrulama Kodu',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : (_otpSent ? _verify : _sendOtp),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_otpSent ? 'Doğrula' : 'Kod Gönder', style: const TextStyle(fontSize: 16)),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() { _otpSent = false; _codeCtrl.clear(); }),
                    child: const Text('Geri'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final bool autoAddBuilding;
  const HomeScreen({super.key, required this.userName, this.autoAddBuilding = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _building;
  List<dynamic> _residents = [];

  StreamSubscription? _callkitSub;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _loadNearby();
    _listenCallKit();
    Future.delayed(const Duration(milliseconds: 800), _checkActiveCall);
    // Yeni kullanıcı: binaya kayıtlı değilse evini eklemeye yönlendir
    if (widget.autoAddBuilding) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAddBuilding());
    }
  }

  Future<void> _openAddBuilding() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBuildingScreen()),
    );
    if (result == true) _loadNearby();
  }


  @override
  void dispose() {
    _callkitSub?.cancel();
    super.dispose();
  }


  Future<void> _checkActiveCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      // ignore: avoid_print
      print('AKTIF CAGRILAR: $calls');
      if (calls is List && calls.isNotEmpty) {
        final call = calls[0];
        final dynamic c = call;
        final extra = (c is CallKitParams ? c.extra : c['extra']) ?? {};
        final callId = (extra['callId'] ?? '').toString();
        final callerUserId = (extra['callerUserId'] ?? '').toString();
        final callerName = (extra['callerName'] ?? 'Bilinmeyen').toString();
        // ignore: avoid_print
        print('CAGRI BILGISI: callId=$callId callerUserId=$callerUserId callerName=$callerName');

        if (callId.isNotEmpty && callerUserId.isNotEmpty && mounted) {
          await FlutterCallkitIncoming.endCall(callId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                peerUserId: callerUserId,
                peerName: callerName,
                isCaller: false,
                incomingCallId: callId,
              ),
            ),
          );
        } else {
          await FlutterCallkitIncoming.endAllCalls();
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('CHECK ACTIVE CALL HATA: $e');
    }
  }

// CallKit olaylarını dinle (kabul/red)
  void _listenCallKit() {
    _callkitSub = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;

      if (event is CallEventActionCallAccept) {
        final extra = event.callKitParams.extra ?? {};
        final callId = (extra['callId'] ?? event.callKitParams.id ?? '').toString();
        final callerUserId = (extra['callerUserId'] ?? '').toString();
        final callerName = (extra['callerName'] ?? 'Bilinmeyen').toString();
        FlutterCallkitIncoming.endCall(callId);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                peerUserId: callerUserId,
                peerName: callerName,
                isCaller: false,
                incomingCallId: callId,
              ),
            ),
          );
        }
      } else if (event is CallEventActionCallDecline) {
        final extra = event.callKitParams.extra ?? {};
        final callId = (extra['callId'] ?? event.callKitParams.id ?? '').toString();
        SocketService.emit('call:reject', {'callId': callId});
      }
    });
  }
  Future<void> _initSocket() async {
    await PushService.init();
    await SocketService.connect();
    SocketService.on('call:incoming', (data) {
      final caller = data['caller'];
      final callId = data['callId'];
      _showIncomingCall(caller['name'] ?? 'Bilinmeyen', caller['id'], callId);
    });
  }

  void _showIncomingCall(String callerName, String callerId, String callId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Gelen Çağrı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 48, color: Color(0xFFE63946)),
            const SizedBox(height: 12),
            Text(callerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('sizi arıyor...'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              SocketService.emit('call:reject', {'callId': callId});
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.call_end, color: Colors.red),
            label: const Text('Reddet', style: TextStyle(color: Colors.red)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    peerUserId: callerId,
                    peerName: callerName,
                    isCaller: false,
                    incomingCallId: callId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.call),
            label: const Text('Kabul Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNearby() async {
    setState(() { _loading = true; _error = null; });
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() { _error = 'Konum izni verilmedi'; _loading = false; });
        return;
      }
      final locEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locEnabled) {
        setState(() { _error = 'Konum servisi kapalı. Lütfen GPS\'i açın.'; _loading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final data = await ApiService.nearby(pos.latitude, pos.longitude);
      if (data['building'] != null) {
        setState(() {
          _building = data['building'];
          _residents = data['residents'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _building = null; _residents = [];
          _error = 'Yakınınızda kayıtlı bina yok'; _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  void _call(String userId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peerUserId: userId,
          peerName: name,
          isCaller: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diafon'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home),
            tooltip: 'Evimi Ekle',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddBuildingScreen()),
              );
              if (result == true) {
                _loadNearby();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              SocketService.disconnect();
              await ApiService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE63946)),
            SizedBox(height: 16),
            Text('Konum alınıyor...'),
          ],
        ),
      );
    }
    if (_error != null && _building == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadNearby,
                icon: const Icon(Icons.refresh),
                label: const Text('Yenile'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE63946).withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.apartment, color: Color(0xFFE63946), size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(_building?['buildingName'] ?? 'Bina', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFE63946)), onPressed: _loadNearby),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('${_residents.length} sakin', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
        Expanded(
          child: _residents.isEmpty
              ? const Center(child: Text('Bu binada kayıtlı sakin yok'))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _residents.length,
            itemBuilder: (context, i) {
              final r = _residents[i];
              final isOnline = r['isOnline'] == true;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                    child: Icon(Icons.person, color: isOnline ? Colors.green : Colors.grey),
                  ),
                  title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Daire ${r['flatNo'] ?? '-'} • Kat ${r['floor'] ?? '-'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? Colors.green : Colors.grey),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _call(r['userId'], r['name'] ?? ''),
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Ara'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}