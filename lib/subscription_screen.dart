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
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _openPayment(String subscriptionId, String period) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(subscriptionId: subscriptionId, period: period),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödeme başarılı! Aboneliğiniz aktif.')),
      );
      _load();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return const Color(0xFF1FA85C);
      case 'trial': return const Color(0xFFE8830C);
      default: return const Color(0xFFE63946);
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'active': return 'Aktif';
      case 'trial': return 'Deneme';
      case 'expired': return 'Süresi Doldu';
      case 'pending_payment': return 'Ödeme Bekleniyor';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Aboneliğim'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.grey))))
              : _subs.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Henüz aboneliğiniz yok.', style: TextStyle(color: Colors.grey, fontSize: 15))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subs.length,
                      itemBuilder: (_, i) {
                        final sub = _subs[i] as Map<String, dynamic>;
                        final status = sub['status']?.toString() ?? 'expired';
                        final daysLeft = sub['daysLeft'] ?? 0;
                        final monthlyPrice = (sub['monthlyPrice'] ?? 0) as num;
                        final yearlyPrice = monthlyPrice * 10; // 2 ay hediye
                        final name = (sub['scopeName'] ?? sub['label'] ?? 'Abonelik').toString();
                        final label = (sub['label'] ?? '').toString();

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(color: Color(0xFF14213D), fontSize: 17, fontWeight: FontWeight.bold)),
                                          if (label.isNotEmpty && label != name)
                                            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _statusColor(status)),
                                      ),
                                      child: Text(_statusText(status), style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                                    const SizedBox(width: 6),
                                    Text(status == 'expired' || status == 'pending_payment'
                                        ? 'Süresi doldu'
                                        : 'Kalan süre: $daysLeft gün',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  ],
                                ),
                                const Divider(height: 24),
                                const Text('Ödeme Seçenekleri', style: TextStyle(color: Color(0xFF14213D), fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _openPayment(sub['id'].toString(), 'monthly'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFE63946),
                                          side: const BorderSide(color: Color(0xFFE63946)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: Column(
                                          children: [
                                            const Text('Aylık', style: TextStyle(fontSize: 12)),
                                            Text('${monthlyPrice.toStringAsFixed(0)} TL', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _openPayment(sub['id'].toString(), 'yearly'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFE63946),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: Column(
                                          children: [
                                            const Text('Yıllık (2 ay hediye)', style: TextStyle(fontSize: 11)),
                                            Text('${yearlyPrice.toStringAsFixed(0)} TL', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
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
