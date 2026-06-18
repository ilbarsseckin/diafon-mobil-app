import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
      );
      // ignore: avoid_print
      print('FCM IZIN: ${settings.authorizationStatus}');

      final token = await _fcm.getToken();
      // ignore: avoid_print
      print('FCM TOKEN: ${token != null ? "alindi (${token.length} karakter)" : "NULL"}');

      if (token != null) {
        await ApiService.saveFcmToken(token);
        // ignore: avoid_print
        print('FCM TOKEN BACKENDE GONDERILDI');
      }

      _fcm.onTokenRefresh.listen((newToken) {
        ApiService.saveFcmToken(newToken);
      });
    } catch (e) {
      // ignore: avoid_print
      print('FCM HATA: $e');
    }
  }
}