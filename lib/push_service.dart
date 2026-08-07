import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'api_service.dart';
class PushService {
  static final _fcm = FirebaseMessaging.instance;
  static Future<void> init() async {
    try {
      final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
      print('FCM IZIN: ' + settings.authorizationStatus.toString());
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
      print('FCM HATA: ' + e.toString());
    }
  }
  static Future<void> _initVoip() async {
    try {
      // Event listener: token hazir oldugunda tetiklenir
      FlutterCallkitIncoming.onEvent.listen((event) async {
        if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
          final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
          if (t != null && t.isNotEmpty) {
            await ApiService.saveVoipToken(t);
            print('VOIP TOKEN (event): gonderildi');
          }
        }
      });
      // Gecikmeli tekrar deneme: token asenkron gelir, birkac kez dene
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        if (t != null && t.isNotEmpty) {
          await ApiService.saveVoipToken(t);
          print('VOIP TOKEN (retry ): gonderildi');
          return;
        }
      }
    } catch (e) {
      print('VOIP HATA: ' + e.toString());
    }
  }
}
