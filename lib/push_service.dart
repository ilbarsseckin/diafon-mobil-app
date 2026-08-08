import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
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
      if (Platform.isIOS) {
        _initVoip();
      }
    } catch (e) {}
  }
  static Future<void> _initVoip() async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(dir.path + '/voip_token.txt');
        if (await file.exists()) {
          final voipToken = (await file.readAsString()).trim();
          if (voipToken.isNotEmpty) {
            await ApiService.saveVoipToken(voipToken);
            print('VOIP TOKEN gonderildi (dosya)');
            return;
          }
        }
      } catch (e) {}
    }
  }
}
