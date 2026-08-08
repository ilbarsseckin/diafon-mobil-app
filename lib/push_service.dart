import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
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
      // iOS VoIP token'i AppDelegate dogrudan backend'e gonderiyor (voip-register)
    } catch (e) {
      print('FCM HATA: ' + e.toString());
    }
  }
}
