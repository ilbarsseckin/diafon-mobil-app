import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
class PushService {
  static final _fcm = FirebaseMessaging.instance;
  static const _voipChannel = MethodChannel('voip_token_channel');
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
    // AppDelegate token'i UserDefaults'a yaziyor. Method channel ile oku.
    // Token asenkron gelir, birkac kez dene.
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final String? voipToken = await _voipChannel.invokeMethod('getVoipToken');
        if (voipToken != null && voipToken.isNotEmpty) {
          await ApiService.saveVoipToken(voipToken);
          print('VOIP TOKEN gonderildi (channel)');
          return;
        }
      } catch (e) {
        print('VOIP channel hata: ' + e.toString());
      }
    }
  }
}
