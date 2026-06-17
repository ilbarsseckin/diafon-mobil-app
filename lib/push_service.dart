import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushService {
  static final _fcm = FirebaseMessaging.instance;

  // Bildirim izni iste + token al + backend'e gönder
  static Future<void> init() async {
    try {
      // İzin iste (Android 13+ ve iOS için)
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // FCM token al
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiService.saveFcmToken(token);
      }

      // Token yenilenince tekrar gönder
      _fcm.onTokenRefresh.listen((newToken) {
        ApiService.saveFcmToken(newToken);
      });
    } catch (e) {
      // sessizce geç
    }
  }
}