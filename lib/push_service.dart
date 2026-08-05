import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'api_service.dart';

class PushService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
      );
      print('FCM IZIN: ${settings.authorizationStatus}');

      final token = await _fcm.getToken();
      print('FCM TOKEN: ${token != null ? "alindi (${token.length} karakter)" : "NULL"}');
      if (token != null) {
        await ApiService.saveFcmToken(token);
        print('FCM TOKEN BACKENDE GONDERILDI');
      }
      _fcm.onTokenRefresh.listen((newToken) {
        ApiService.saveFcmToken(newToken);
      });

      // iOS: kilitli ekranda calan cagri icin VoIP push sart.
      if (Platform.isIOS) {
        await _initVoip();
      }
    } catch (e) {
      print('FCM HATA: $e');
    }
  }

  static Future<void> _initVoip() async {
    try {
      final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (voipToken != null && voipToken.isNotEmpty) {
        await ApiService.saveVoipToken(voipToken);
        print('VOIP TOKEN GONDERILDI (${voipToken.length} karakter)');
      }

      FlutterCallkitIncoming.onEvent.listen((event) async {
        if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
          final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
          if (t != null && t.isNotEmpty) {
            await ApiService.saveVoipToken(t);
            print('VOIP TOKEN YENILENDI');
          }
        }
      });
    } catch (e) {
      print('VOIP TOKEN HATA: $e');
    }
  }
}
