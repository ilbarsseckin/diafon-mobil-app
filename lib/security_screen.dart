import 'package:flutter/material.dart';
import 'call_screen.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield, size: 56, color: Color(0xFFE63946)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Güvenliği Ara',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Binanızın güvenlik görevlisine sesli/görüntülü çağrı başlatın. '
                    'İlk açan güvenlik görevlisi çağrıyı alır.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // Güvenlik çağrısı: tek bir peer yok, binanın
                        // güvenliklerine gider. CallScreen callType='security'
                        // iken 'call:start-security' event'ini emit eder.
                        builder: (_) => const CallScreen(
                          peerUserId: '',
                          peerName: 'Güvenlik',
                          isCaller: true,
                          callType: 'security',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield),
                  label: const Text('Güvenliği Ara', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}