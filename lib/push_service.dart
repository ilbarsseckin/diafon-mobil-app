import ''dart:io'' show Platform;
import ''package:firebase_messaging/firebase_messaging.dart'';
import ''package:flutter_callkit_incoming/entities/call_event.dart'';
import ''package:flutter_callkit_incoming/flutter_callkit_incoming.dart'';
import ''api_service.dart'';
class PushService {
  static final _fcm = FirebaseMessaging.instance;
  static Future<void> init() async {
    try {
      final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
      print(''FCM IZIN: ${settings.authorizationStatus}'');
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiService.saveFcmToken(token);
      }
      _fcm.onTokenRefresh.listen((newToken) {
        ApiService.saveFcmToken(newToken);
      });
      if (Platform.isIOS) {
        await _initVoip();
      }
    } catch (e) {
      print(''FCM HATA: $e'');
    }
  }
  static Future<void> _initVoip() async {
    try {
      final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      // DEBUG: durumu backende yaz
      final durum = (voipToken == null)
          ? ''DBG_NULL''
          : (voipToken.isEmpty ? ''DBG_EMPTY'' : voipToken);
      await ApiService.saveVoipToken(durum);
      FlutterCallkitIncoming.onEvent.listen((event) async {
        if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
          final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
          await ApiService.saveVoipToken(t == null ? ''DBG_EVT_NULL'' : (t.isEmpty ? ''DBG_EVT_EMPTY'' : t));
        }
      });
    } catch (e) {
      await ApiService.saveVoipToken(''DBG_ERR'');
    }
  }
}
