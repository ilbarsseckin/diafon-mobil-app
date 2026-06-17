import 'package:flutter/material.dart';
import 'api_service.dart';

void main() {
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
      home: const LoginScreen(),
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

  bool _otpSent = false;   // OTP gönderildi mi
  bool _loading = false;
  String? _error;

  // OTP gönder (kayıt veya giriş)
  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      final phone = _phoneCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      // İsim doluysa kayıt dene, değilse giriş
      if (name.isNotEmpty) {
        try {
          await ApiService.register(name, phone);
        } catch (e) {
          // Zaten kayıtlıysa login'e düş
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

  // OTP doğrula
  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.verify(_phoneCtrl.text.trim(), _codeCtrl.text.trim());
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(userName: data['user']['name'])),
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

// Geçici ana ekran (sonra harita/sakin listesi olacak)
class HomeScreen extends StatelessWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diafon'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('Hoş geldin, $userName!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Giriş başarılı. Sıradaki: harita + sakin listesi.'),
          ],
        ),
      ),
    );
  }
}