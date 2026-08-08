import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
class PushService {
  static final _fcm = FirebaseMessaging.instance;
  static Future<void> init() async {
    try {
      final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiService.saveFcmToken(token);
      }
      _fcm.onTokenRefresh.listen((newToken) {
        ApiService.saveFcmToken(newToken);
      });
      if (Platform.isIOS) {
        _initVoip();
      }
    } catch (e) {}
  }
  static Future<void> _dbg(String msg) async {
    try {
      await http.post(
        Uri.parse('https://mobildiafon.com/api/auth/voip-debug'),
        headers: {'Content-Type': 'application/json'},
        body: '{"dbg":"' + msg + '"}',
      );
    } catch (e) {}
  }
  static Future<void> _initVoip() async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final keys = prefs.getKeys().toList();
        final voipToken = prefs.getString('voip_device_token');
        if (i == 3) {
          await _dbg('anahtarlar=' + keys.join(','));
        }
        if (voipToken != null && voipToken.isNotEmpty) {
          await _dbg('TOKEN_BULUNDU_len=' + voipToken.length.toString());
          await ApiService.saveVoipToken(voipToken);
          return;
        }
      } catch (e) {
        await _dbg('HATA=' + e.toString());
      }
    }
    await _dbg('TOKEN_BULUNAMADI_20_deneme');
  }
}
