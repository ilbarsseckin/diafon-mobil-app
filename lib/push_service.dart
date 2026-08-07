import 'dart:io' show Platform;
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
      final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      String durum;
      if (voipToken == null) {
        durum = 'DBG_NULL';
      } else if (voipToken.isEmpty) {
        durum = 'DBG_EMPTY';
      } else {
        durum = voipToken;
      }
      await ApiService.saveVoipToken(durum);
      FlutterCallkitIncoming.onEvent.listen((event) async {
        if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
          final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
          String d2;
          if (t == null) {
            d2 = 'DBG_EVT_NULL';
          } else if (t.isEmpty) {
            d2 = 'DBG_EVT_EMPTY';
          } else {
            d2 = t;
          }
          await ApiService.saveVoipToken(d2);
        }
      });
    } catch (e) {
      await ApiService.saveVoipToken('DBG_ERR');
    }
  }
}
