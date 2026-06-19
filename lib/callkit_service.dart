import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

class CallKitService {
  static Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerUserId,
    String? callerPhotoUrl,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Diafon',
      avatar: (callerPhotoUrl != null && callerPhotoUrl.isNotEmpty) ? callerPhotoUrl : null,
      handle: 'Gelen Çağrı',
      type: 1,
      duration: 30000,
      extra: <String, dynamic>{
        'callId': callId,
        'callerUserId': callerUserId,
        'callerName': callerName,
        'callerPhoto': callerPhotoUrl ?? '',
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#E63946',
        actionColor: '#4CAF50',
        isShowCallID: false,
        isImportant: true,
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static Future<void> endCall(String callId) async {
    await FlutterCallkitIncoming.endCall(callId);
  }

  static Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }
}