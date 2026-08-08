import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    } catch (e) {
      print('FCM HATA: ' + e.toString());
    }
  }
  static Future<void> _initVoip() async {
    // AppDelegate token'i UserDefaults'a yaziyor. shared_preferences ile oku.
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final voipToken = prefs.getString('voip_device_token');
        if (voipToken != null && voipToken.isNotEmpty) {
          await ApiService.saveVoipToken(voipToken);
          print('VOIP TOKEN gonderildi (prefs)');
          return;
        }
      } catch (e) {
        print('VOIP prefs hata: ' + e.toString());
      }
    }
  }
}
