import 'package:diafon_mobil_app/vehicle_activate_screen.dart';
import 'package:diafon_mobil_app/vehicle_contact_screen.dart';
import 'package:diafon_mobil_app/vehicles_screen.dart';
import 'package:diafon_mobil_app/webview_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'add_building_screen.dart';
import 'api_service.dart';
import 'connectivity_banner.dart';
import 'homes_screen.dart';
import 'location_action_screen.dart';
import 'onboarding_screen.dart';
import 'socket_service.dart';
import 'call_screen.dart';
import 'settings_screen.dart';
import 'push_service.dart';
import 'callkit_service.dart';
import 'qr_scan_screen.dart';
import 'call_history_screen.dart';
import 'nearby_screen.dart';
import 'background_service.dart';
import 'permissions_screen.dart';
// Arka planda/kapalıyken gelen FCM mesajını yakalar
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] == 'call_cancelled') {
    await FlutterCallkitIncoming.endAllCalls();
    return;
  }
  if (data['type'] == 'doorbell') {
    await showDoorbellNotification(
      data['visitorName']?.toString() ?? 'Ziyaretçi',
      data['buildingName']?.toString() ?? '',
    );
    return;
  }
  if (data['type'] == 'incoming_call') {
    final photo = (data['callerPhoto'] ?? '').toString();
    final fullPhoto = (photo.isNotEmpty && !photo.startsWith('http'))
        ? 'https://mobildiafon.com$photo'
        : photo;
    await CallKitService.showIncomingCall(
      callId: data['callId'] ?? '',
      callerName: data['callerName'] ?? 'Bilinmeyen',
      callerUserId: data['callerUserId'] ?? '',
      callerPhotoUrl: fullPhoto,
      buildingId: (data['buildingId'] ?? '').toString(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (e) {}
  try {
    await initBackgroundService();
  } catch (e) {
    print('FG SERVICE HATA: $e');   // patlarsa uygulama yine açılsın
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
      builder: (context, child) {
        return ConnectivityBanner(child: child ?? const SizedBox.shrink());
      },
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
    _bootstrapCallPermissions();
    _check();
  }

  Future<void> _bootstrapCallPermissions() async {
    // Android 13+ bildirim izni
    await Permission.notification.request();
    await Permission.microphone.request();
    await Permission.camera.request();
    // Android 14+/16: CallKit'in kilit ekraninda tam ekran acabilmesi icin
    try {
      final canFull = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (canFull == false) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (_) {}
  }

  Future<void> _check() async {
    final token = await ApiService.getToken();
    final name = await ApiService.getUserName();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      // Onboarding görülmediyse önce tanıtımı göster
      final seen = await ApiService.getOnboardingSeen();
      if (!mounted) return;
      if (!seen) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (obCtx) => OnboardingScreen(
              onFinish: () {
                Navigator.pushReplacement(
                  obCtx,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
        );
        return;
      }
      // Misafir modu daha önce seçildiyse direkt misafir ana ekran
      final guest = await ApiService.getGuestMode();
      if (!mounted) return;
      if (guest) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(userName: 'Misafir', autoAddBuilding: false, guest: true),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    bool registered = true;
    try {
      final status = await ApiService.myBuildingStatus();
      registered = status['registered'] == true;
    } catch (e) {
      // hata olursa yine de ana ekrana git
    }
    // Bina yoksa bile aracı varsa kurulum ekranını açma
    // Bina yoksa bile aracı varsa kurulum ekranını açma
    print('OTURUM: bina registered=$registered');
    if (!registered) {
      try {
        final vehicles = await ApiService.myVehicles();
        print('OTURUM: arac sayisi=${vehicles.length}');
        if (vehicles.isNotEmpty) registered = true;
      } catch (e) {
        print('OTURUM: arac hatasi=$e');
      }
    }
    print('OTURUM: sonuc registered=$registered');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(userName: name ?? '', autoAddBuilding: !registered),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // MD amblemi
            Image.asset(
              'assets/logo.webp',
              width: 220,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.doorbell, size: 90, color: Colors.white),
            ),
            const SizedBox(height: 24),
            // MobilDiafon yazısı
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: Color(0xFFE63946), strokeWidth: 2.5),
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

enum _LoginStep { phone, name, otp }

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _LoginStep _step = _LoginStep.phone;
  bool _loading = false;
  String? _error;
  bool _kvkkOk = false;
  Timer? _otpTimer;
  int _otpSeconds = 0;

  void _startOtpTimer() {
    _otpTimer?.cancel();
    setState(() => _otpSeconds = 120);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_otpSeconds <= 1) {
        t.cancel();
        setState(() => _otpSeconds = 0);
      } else {
        setState(() => _otpSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.login(_phoneCtrl.text.trim());
      _startOtpTimer();
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }
  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }
  Future<void> _continuePhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Geçerli bir telefon numarası girin');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.login(phone);
      setState(() { _step = _LoginStep.otp; _loading = false; });
      _startOtpTimer();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('kayıtlı değil')) {
        FocusScope.of(context).unfocus();
        setState(() { _step = _LoginStep.name; _loading = false; });
      } else {
        setState(() { _error = msg.replaceAll('Exception: ', ''); _loading = false; });
      }
    }
  }

  Future<void> _continueName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Adınızı girin');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.register(name, _phoneCtrl.text.trim());
      setState(() { _step = _LoginStep.otp; _loading = false; });
      _startOtpTimer();
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Doğrulama kodunu girin');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.verify(_phoneCtrl.text.trim(), _codeCtrl.text.trim());
      bool registered = true;
      try {
        final status = await ApiService.myBuildingStatus();
        registered = status['registered'] == true;
      } catch (_) {}
      // Bina yoksa bile aracı varsa kurulum ekranını açma
      if (!registered) {
        try {
          final vehicles = await ApiService.myVehicles();
          if (vehicles.isNotEmpty) registered = true;
        } catch (_) {}
      }
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
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }
  Future<void> _continueGuest() async {
    // Misafir modu tercihini hatırla (kapatıp açınca login sorma)
    await ApiService.setGuestMode(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(userName: 'Misafir', autoAddBuilding: false, guest: true),
      ),
    );
  }
  void _back() {
    setState(() {
      _error = null;
      if (_step == _LoginStep.otp) {
        _step = _nameCtrl.text.trim().isEmpty ? _LoginStep.phone : _LoginStep.name;
        _codeCtrl.clear();
      } else if (_step == _LoginStep.name) {
        _step = _LoginStep.phone;
        _nameCtrl.clear();
      }
    });
  }

  String get _title {
    switch (_step) {
      case _LoginStep.phone: return 'Telefon numaranızı girin';
      case _LoginStep.name: return 'Hoş geldiniz! Adınızı girin';
      case _LoginStep.otp: return 'Doğrulama kodunu girin';
    }
  }

  String get _buttonText {
    switch (_step) {
      case _LoginStep.otp: return 'Giriş Yap';
      default: return 'Devam';
    }
  }

  VoidCallback get _action {
    switch (_step) {
      case _LoginStep.phone: return _continuePhone;
      case _LoginStep.name: return _continueName;
      case _LoginStep.otp: return _verify;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.network(
                  'https://cdn.mobildiafon.com/logo/logo.webp',
                  height: 70,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => const Text('MobilDiafon',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE63946))),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 6),
                Text(_title,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                const SizedBox(height: 36),
                if (_step == _LoginStep.phone)
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Telefon',
                      hintText: '05xxxxxxxxx',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                if (_step == _LoginStep.name)
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                if (_step == _LoginStep.otp) ...[
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '______',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _otpSeconds > 0
                        ? Text(
                      'Kodu tekrar gönder (${(_otpSeconds ~/ 60)}:${(_otpSeconds % 60).toString().padLeft(2, '0')})',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    )
                        : TextButton(
                      onPressed: _loading ? null : _resendOtp,
                      child: const Text('Kodu Tekrar Gönder', style: TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
                // KVKK onayı (sadece telefon adımında)
                if (_step == _LoginStep.phone) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24, height: 24,
                        child: Checkbox(
                          value: _kvkkOk,
                          activeColor: const Color(0xFFE63946),
                          onChanged: (v) => setState(() => _kvkkOk = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
                              children: [
                                TextSpan(
                                  text: 'KVKK Aydınlatma Metni',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE63946)),
                                  recognizer: TapGestureRecognizer()..onTap = () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const WebViewScreen(url: 'https://mobildiafon.com/kvkk', title: 'KVKK Aydınlatma Metni'),
                                    ));
                                  },
                                ),
                                const TextSpan(text: ' ve ', style: TextStyle(color: Colors.grey)),
                                TextSpan(
                                  text: 'Kullanım Şartları',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE63946)),
                                  recognizer: TapGestureRecognizer()..onTap = () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const WebViewScreen(url: 'https://mobildiafon.com/kullanim-sartlari', title: 'Kullanım Şartları'),
                                    ));
                                  },
                                ),
                                const TextSpan(text: '\'nı okudum, kabul ediyorum.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (_loading || (_step == _LoginStep.phone && !_kvkkOk)) ? null : _action,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (_step == _LoginStep.phone) ...[
                  const SizedBox(height: 16),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('veya', style: TextStyle(color: Colors.grey))),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: (_loading || !_kvkkOk) ? null : _continueGuest,
                    icon: const Icon(Icons.person_outline, color: Color(0xFF14213D)),
                    label: const Text('Misafir olarak devam et', style: TextStyle(color: Color(0xFF14213D), fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                if (_step == _LoginStep.otp) ...[
                  const SizedBox(height: 4),
                  Text('${_phoneCtrl.text} numarasına kod gönderildi',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
  final bool guest;
  const HomeScreen({super.key, required this.userName, this.autoAddBuilding = false, this.guest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  List<dynamic> _buildings = [];

  StreamSubscription? _callkitSub;
  int _deletionDaysLeft = -1;
  Map<String, dynamic>? _trialInfo; // deneme/abonelik durumu (toolbar rozeti)
  bool _dnd = false;

  List<String> _eksikIzinler = [];

  Future<void> _checkNotifPermission() async {
    final eksik = <String>[];
    if (!await Permission.notification.isGranted) eksik.add('Bildirim');
    if (!await Permission.microphone.isGranted) eksik.add('Mikrofon');
    if (!await Permission.camera.isGranted) eksik.add('Kamera');
    if (mounted && eksik.join(',') != _eksikIzinler.join(',')) {
      setState(() => _eksikIzinler = eksik);
    }
  }
  Widget _notifBanner() {
    return Material(
      color: const Color(0xFFE63946),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PermissionsScreen()),
          );
          _checkNotifPermission();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.notifications_off, color: Colors.white, size: 20),
              const SizedBox(width: 10),
          Expanded(
            child: Text(
              _eksikIzinler.length == 1
                  ? '${_eksikIzinler.first} izni kapalı — uygulama düzgün çalışmayabilir'
                  : '${_eksikIzinler.join(", ")} izinleri kapalı — uygulama düzgün çalışmayabilir',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Aç',
                    style: TextStyle(
                        color: Color(0xFFE63946), fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNotifPermission();
  }
  Future<void> _checkDnd() async {
    try {
      final v = await ApiService.getDndMode();
      if (mounted) setState(() => _dnd = v);
    } catch (_) {}
  }

  Future<void> _checkSubscription() async {
    if (widget.guest) return;
    try {
      final res = await ApiService.mySubscription();
      final subs = (res['subscriptions'] as List?) ?? [];
      if (subs.isEmpty) return;
      // En kritik durumu bul: expired > trial(az gün) > active
      Map<String, dynamic>? kritik;
      for (final s in subs) {
        final sm = s as Map<String, dynamic>;
        final st = sm['status']?.toString();
        if (st == 'expired' || st == 'pending_payment') { kritik = sm; break; }
        if (sm['isTrial'] == true) kritik = sm;
      }
      if (mounted && kritik != null) setState(() => _trialInfo = kritik);
    } catch (_) {}
  }

  Future<void> _checkDeletionStatus() async {
    if (widget.guest) return;
    try {
      final res = await ApiService.deletionStatus();
      if (mounted && res['pending'] == true) {
        setState(() => _deletionDaysLeft = (res['daysLeft'] ?? 0) as int);
      }
    } catch (_) {}
  }

  Future<void> _cancelDeletion() async {
    try {
      final res = await ApiService.cancelDeletion();
      if (mounted && res['success'] == true) {
        setState(() => _deletionDaysLeft = -1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesap silme talebi iptal edildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }
  @override
  void initState() {
    super.initState();
    _initSocket();
    _loadNearby();
    _listenCallKit();
    _checkDeletionStatus();
    _checkSubscription();
    _checkDnd();
    Future.delayed(const Duration(milliseconds: 800), _checkActiveCall);
    if (widget.autoAddBuilding) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAddBuilding());
    }
    WidgetsBinding.instance.addObserver(this);
    _checkNotifPermission();
  }

  Future<void> _openAddBuilding() async {
    // Kurulum ekrani sadece bir kez gosterilir
    if (await ApiService.actionScreenShown()) return;
    await ApiService.setActionScreenShown();
    if (!mounted) return;
    // Misafir ise Ã¼yeliÄŸe yÃ¶nlendir
    if (widget.guest) {
      _showGuestPrompt();
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationActionScreen()),
    );
    if (result == true) _loadNearby();
  }

  // Misafir bir üyelik özelliğine dokununca: nazik uyarı + giriş ekranı
  void _showGuestPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFFE63946)),
            SizedBox(width: 10),
            Expanded(child: Text('Üyelik Gerekli', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: const Text(
          'Ev eklemek, yönetici olmak ve görüntülü çağrı almak için üye olmanız gerekir. '
              'Misafir olarak yakındaki yerleri görebilir ve QR ile arama yapabilirsiniz.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            onPressed: () async {
              await ApiService.setGuestMode(false);
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Üye Ol / Giriş Yap'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _callkitSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Uygulama kapalıyken CallKit'ten kabul edilmiş çağrıyı yakala
  Future<void> _checkActiveCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      print('AKTIF CAGRILAR: $calls');
      if (calls is List && calls.isNotEmpty) {
        final dynamic call = calls[0];
        final extra = (call is CallKitParams ? call.extra : (call is Map ? call['extra'] : null)) ?? {};
        final callId = (extra['callId'] ?? '').toString();
        final callerUserId = (extra['callerUserId'] ?? '').toString();
        final callerName = (extra['callerName'] ?? 'Bilinmeyen').toString();
        final buildingId = (extra['buildingId'] ?? '').toString();
        print('AKTIF CAGRI: callId=$callId callerUserId=$callerUserId');

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
                buildingId: buildingId.isNotEmpty ? buildingId : null,
              ),
            ),
          );
        } else {
          await FlutterCallkitIncoming.endAllCalls();
        }
      }
    } catch (e) {
      print('CHECK ACTIVE CALL HATA: $e');
    }
  }

  void _listenCallKit() {
    _callkitSub = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      if (event is CallEventActionCallAccept) {
        final extra = event.callKitParams.extra ?? {};
        final callId = (extra['callId'] ?? event.callKitParams.id ?? '').toString();
        final callerUserId = (extra['callerUserId'] ?? '').toString();
        final callerName = (extra['callerName'] ?? 'Bilinmeyen').toString();
        final buildingId = (extra['buildingId'] ?? '').toString();
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
                buildingId: buildingId.isNotEmpty ? buildingId : null,
              ),
            ),
          );
        }
      } else if (event is CallEventActionCallDecline) {
        final extra = event.callKitParams.extra ?? {};
        final callId = (extra['callId'] ?? event.callKitParams.id ?? '').toString();
        // Once REST ile reddet (arka planda soket bagli olmayabilir, en garantisi bu)
        if (callId.isNotEmpty) {
          ApiService.rejectCall(callId);
        }
        // Uygulama aciksa soket emit'i de ekstra guvence olsun
        () async {
          if (!SocketService.isConnected) {
            await SocketService.connect();
            int waited = 0;
            while (!SocketService.isConnected && waited < 3000) {
              await Future.delayed(const Duration(milliseconds: 200));
              waited += 200;
            }
          }
          SocketService.emit('call:reject', {'callId': callId});
        }();
      }
    });
  }

  Future<void> _initSocket() async {
    await PushService.init();
    // Uygulama ACIKKEN gelen FCM (iptal vb.)
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      if (data['type'] == 'call_cancelled') {
        FlutterCallkitIncoming.endAllCalls();
      } else if (data['type'] == 'doorbell') {
        showDoorbellNotification(
          data['visitorName']?.toString() ?? 'Ziyaretçi',
          data['buildingName']?.toString() ?? '',
        );
      }
    });
    await SocketService.connect();
    SocketService.on('call:incoming', (data) {
      final caller = data['caller'];
      final callId = data['callId'];
      _showIncomingCall(
        caller['name'] ?? 'Bilinmeyen',
        caller['id'],
        callId,
        caller['photoUrl']?.toString(),
        data['buildingId']?.toString(),
      );
    });
    SocketService.on('call:taken', (data) {
      FlutterCallkitIncoming.endAllCalls();
    });
  }

  void _showIncomingCall(String callerName, String callerId, String callId, [String? photoUrl, String? buildingId]) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Gelen Çağrı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFE63946).withValues(alpha: 0.1),
              backgroundImage: hasPhoto ? NetworkImage(ApiService.fullPhotoUrl(photoUrl)) : null,
              onBackgroundImageError: hasPhoto ? (_, __) {} : null,
              child: !hasPhoto
                  ? const Icon(Icons.person, size: 40, color: Color(0xFFE63946))
                  : null,
            ),
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
                    buildingId: buildingId,
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

  // --- Ana ekran: yakindaki binalari listele ---
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
      final list = await ApiService.nearbyVisible(pos.latitude, pos.longitude);
      setState(() {
        _buildings = list;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  IconData _iconFor(Map<String, dynamic> b) {
    if (b['type'] == 'business') {
      switch (b['businessCategory']) {
        case 'saglik': return Icons.local_hospital;
        case 'market': return Icons.shopping_cart;
        case 'yeme': return Icons.restaurant;
        case 'kuafor': return Icons.content_cut;
        case 'ofis': return Icons.business_center;
        default: return Icons.store;
      }
    }
    return Icons.apartment;
  }

  String _subtitle(Map<String, dynamic> b) {
    final dist = b['distance'];
    final distStr = dist != null ? '$dist m' : '';
    if (b['type'] == 'business') {
      return 'İşyeri · $distStr';
    }
    final units = b['flatCount'] ?? 0;
    return '$units daire · $distStr';
  }

  Future<void> _openBuilding(Map<String, dynamic> b) async {
    // QR+Konum modu ise uyar (aramak için QR gerekli)
    if (b['securityMode'] == 'both') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('QR Gerekli'),
          content: Text('${b['buildingName']} aramak için kapıdaki QR kodu okutmanız gerekiyor.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
      return;
    }
    // Konum modu: binanın sakinlerini çek (by-qr token ile) ve göster
    final token = b['qrToken'] as String?;
    if (token == null) return;
    try {
      final data = await ApiService.nearbyByQr(token);
      final residents = (data['residents'] as List?) ?? [];
      if (!mounted) return;
      if (residents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aranabilecek kişi yok')));
        return;
      }
      // İşyeri (tek birim) → direkt ara
      if (b['type'] == 'business' && residents.length == 1) {
        _callResident(residents[0], b);
        return;
      }
      // Apartman → sakin/daire listesi göster
      _showResidents(residents, b);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilgiler alınamadı')));
    }
  }

  void _showResidents(List<dynamic> residents, Map<String, dynamic> b) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSheetState) {
              String query = '';
              var filtered = residents;
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.6,
                builder: (_, controller) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(b['buildingName'] ?? 'Bina',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Daire no veya isim ara...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF2F4F8),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          setSheetState(() {
                            query = v.trim().toLowerCase();
                            filtered = query.isEmpty
                                ? residents
                                : residents.where((r) {
                              final rr = r as Map<String, dynamic>;
                              final name = (rr['name'] ?? '').toString().toLowerCase();
                              final flat = (rr['flatNo'] ?? '').toString().toLowerCase();
                              return name.contains(query) || flat.contains(query);
                            }).toList();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Sonuç bulunamadı', style: TextStyle(color: Colors.grey)),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final r = filtered[i] as Map<String, dynamic>;
                  final photo = (r['photoUrl'] ?? '').toString();
                  final isOnline = r['isOnline'] == true;
                  final hasPhoto = photo.isNotEmpty;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                      backgroundImage: hasPhoto ? NetworkImage(ApiService.fullPhotoUrl(photo)) : null,
                      onBackgroundImageError: hasPhoto ? (_, __) {} : null,
                      child: !hasPhoto
                          ? Icon(Icons.person, color: isOnline ? Colors.green : Colors.grey)
                          : null,
                    ),
                    title: Text(r['name'] ?? 'İsimsiz'),
                    subtitle: Text('Daire ${r['flatNo'] ?? '?'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _ringDoorbell(r),
                          icon: const Icon(Icons.notifications_active, color: Color(0xFFE8830C)),
                          tooltip: 'Zil Çal',
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () { Navigator.pop(ctx); _callResident(r, b); },
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('Ara'),
                        ),
                      ],
                    ),
                  );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
        ),
    );
  }

  Future<void> _ringDoorbell(Map<String, dynamic> r) async {
    final apartmentId = (r['apartmentId'] ?? '').toString();
    if (apartmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu sakine zil çalınamıyor')));
      return;
    }
    final name = r['name'] ?? 'Sakin';
    try {
      final res = await ApiService.ringDoorbell(apartmentId: apartmentId);
      if (mounted) {
        if (res['code'] == 'SUBSCRIPTION_EXPIRED') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Şu anda bu binaya zil çalınamıyor. Lütfen bina yönetimiyle iletişime geçin.'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['success'] == true ? '🔔 $name için zil çalındı' : (res['message']?.toString() ?? 'Zil çalınamadı'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }
  void _callResident(Map<String, dynamic> r, Map<String, dynamic> b) {
    final userId = r['userId'] ?? '';
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peerUserId: userId,
          peerName: r['name'] ?? 'Sakin',
          isCaller: true,
          buildingId: b['id'] as String?,
        ),
      ),
    );
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

  void _callSecurity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CallScreen(
          peerUserId: '',
          peerName: 'Güvenlik',
          isCaller: true,
          callType: 'security',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Yakındakiler'),
            if (_dnd) ...[
              const SizedBox(width: 8),
              const Icon(Icons.do_not_disturb_on, size: 18, color: Colors.white70),
            ],
          ],
        ),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadNearby,
          ),
          if (!widget.guest)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Ayarlar',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
        ],
      ),body: Column(
      children: [
        if (widget.guest) _guestBanner(),
        if (_deletionDaysLeft >= 0) _deletionBanner(),
        if (_eksikIzinler.isNotEmpty && !widget.guest) _notifBanner(),

        Expanded(child: _buildBody()),
      ],
    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanQr,
        backgroundColor: const Color(0xFFE63946),
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: widget.guest
          ? null
          : BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _bottomBarItem(
                  icon: Icons.home,
                  label: 'Evlerim',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Evlerim'),
                            backgroundColor: const Color(0xFFE63946),
                            foregroundColor: Colors.white,
                          ),
                          body: const HomesScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: _bottomBarItem(
                  icon: Icons.directions_car,
                  label: 'Araçlar',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VehiclesScreen(),
                      ),
                    );
                  },
                ),
              ),

              // Ortadaki QR butonu için alan
              const SizedBox(width: 72),

              Expanded(
                child: _bottomBarItem(
                  icon: Icons.shield,
                  label: 'Güvenlik',
                  onTap: _callSecurity,
                ),
              ),

              Expanded(
                child: _bottomBarItem(
                  icon: Icons.history,
                  label: 'Çağrılar',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CallHistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBarItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFE63946), size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, color: Color(0xFFE63946)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _scanQr() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || raw.isEmpty) return;
    print('QR HAM: $raw');
    // Arac QR mi bina QR mi?
    final uri = Uri.tryParse(raw);
    final vehCode = uri?.queryParameters['code'];
    if (vehCode != null && vehCode.isNotEmpty) {
      await _handleVehicleQr(vehCode);
      return;
    }
    final token = uri?.queryParameters['token'] ?? raw;

    try {
      final data = await ApiService.nearbyByQr(token);
      final residents = (data['residents'] as List?) ?? [];
      final building = data['building'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (building == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçersiz QR kod')));
        return;
      }
      if (residents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu binada aranabilecek kişi yok')));
        return;
      }
      _showResidents(residents, {
        'buildingName': building['buildingName'] ?? 'Bina',
        'id': building['id'],
        'type': building['type'] ?? 'residential',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _handleVehicleQr(String code) async {
    try {
      final v = await ApiService.lookupVehicle(code);
      if (!mounted) return;
      print('ARAC LOOKUP: kod=$code yanit=$v');
      if (v['found'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geçersiz araç kartı')));
        return;
      }

      // Henuz aktive edilmemis kart -> aktivasyon ekrani
      if (v['canCall'] != true) {
        if (widget.guest) {
          _showGuestPrompt();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VehicleActivateScreen(initialCode: code)),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleContactScreen(code: code, data: v),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }
  Widget _guestBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE63946), Color(0xFFC1121F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE63946).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Evinizi dijitalleştirin',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Üye olun; ev veya işyerinizi ekleyin, ziyaretçilerinizle görüntülü görüşün.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () async {
              await ApiService.setGuestMode(false);
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE63946),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Üye Ol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _deletionBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hesabınız $_deletionDaysLeft gün sonra silinecek',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 14),
                ),
                Text(
                  'Vazgeçtiyseniz iptal edebilirsiniz.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _cancelDeletion,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('İptal Et', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
    if (_error != null) {
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
    if (_buildings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_off, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Yakında görünür bina yok',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Bu konumda kayıtlı bina/işyeri bulunamadı.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
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
    return RefreshIndicator(
      onRefresh: _loadNearby,
      color: const Color(0xFFE63946),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _buildings.length,
        itemBuilder: (_, i) {
          final b = _buildings[i] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: b['type'] == 'business' ? Colors.orange.shade50 : Colors.blue.shade50,
                child: Icon(_iconFor(b),
                    color: b['type'] == 'business' ? Colors.orange : Colors.blue),
              ),
              title: Text(b['buildingName'] ?? 'Bina',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_subtitle(b)),
              trailing: b['securityMode'] == 'both'
                  ? const Icon(Icons.qr_code, color: Colors.grey)
                  : const Icon(Icons.chevron_right),
              onTap: () => _openBuilding(b),
            ),
          );
        },
      ),
    );
  }
}