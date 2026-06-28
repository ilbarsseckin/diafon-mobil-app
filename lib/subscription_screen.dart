import 'package:flutter/material.dart';
import 'api_service.dart';
import 'payment_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _subs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.mySubscription();
      setState(() {
        _subs = data['subscriptions'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openPayment(String subscriptionId, String period) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          subscriptionId: subscriptionId,
          period: period,
        ),
      ),
    );
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödeme başarılı! Aboneliğiniz aktif.')),
      );
      _load();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'trial': return Colors.orange;
      default: return Colors.red;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'active': return 'Aktif';
      case 'trial': return 'Deneme';
      case 'expired': return 'Süresi Doldu';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonelik'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _subs.isEmpty
          ? const Center(child: Text('Abonelik bulunamadı.', style: TextStyle(color: Colors.white)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _subs.length,
        itemBuilder: (_, i) {
          final sub = _subs[i];
          final status = sub['status'] ?? 'expired';
          final daysLeft = sub['daysLeft'] ?? 0;
          final monthlyPrice = sub['monthlyPrice'] ?? 0;
          final yearlyPrice = sub['yearlyPrice'] ?? 0;
          final buildingName = sub['buildingName'] ?? 'Bina';

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(buildingName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _statusColor(status)),
                        ),
                        child: Text(_statusText(status),
                            style: TextStyle(color: _statusColor(status), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Kalan süre: $daysLeft gün',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openPayment(sub['id'], 'monthly'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                          ),
                          child: Text('Aylık ₺$monthlyPrice'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openPayment(sub['id'], 'yearly'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Yıllık ₺$yearlyPrice'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}