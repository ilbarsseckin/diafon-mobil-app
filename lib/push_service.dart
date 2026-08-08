import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
class PushService {
  static final _fcm = FirebaseMessaging.instance;
  static Future<void> _dbg(String msg) async {
    try {
      await http.post(
        Uri.parse('https://mobildiafon.com/api/auth/voip-debug'),
        headers: {'Content-Type': 'application/json'},
        body: '{"dbg":"' + msg + '"}',
      );
    } catch (e) {}
  }
  static Future<void> init() async {
    await _dbg('INIT_BASLADI');
    try {
      final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiService.saveFcmToken(token);
      }
      _fcm.onTokenRefresh.listen((newToken) {
        ApiService.saveFcmToken(newToken);
      });
      await _dbg('PLATFORM_' + (Platform.isIOS ? 'IOS' : 'DIGER'));
      if (Platform.isIOS) {
        _initVoip();
      }
    } catch (e) {
      await _dbg('INIT_HATA_' + e.toString().substring(0, 15));
    }
  }
  static Future<void> _initVoip() async {
    await _dbg('VOIP_BASLADI');
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(dir.path + '/voip_token.txt');
        final varmi = await file.exists();
        if (i == 2) {
          await _dbg('DOSYA_' + (varmi ? 'VAR' : 'YOK') + '_yol_' + dir.path.length.toString());
        }
        if (varmi) {
          final voipToken = (await file.readAsString()).trim();
          if (voipToken.isNotEmpty) {
            await _dbg('TOKEN_OKUNDU_len' + voipToken.length.toString());
            await ApiService.saveVoipToken(voipToken);
            return;
          }
        }
      } catch (e) {
        await _dbg('VOIP_HATA_' + e.toString().substring(0, 15));
      }
    }
    await _dbg('VOIP_BITTI_TOKEN_YOK');
  }
}
