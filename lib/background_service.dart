import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  Timer.periodic(const Duration(seconds: 60), (_) {});
}

Future<void> initBackgroundService() async {
  final fln = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    'diafon_fg',
    'Diafon Servis',
    description: 'Cagrilara hazir',
    importance: Importance.low,
  );
  await fln
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
      notificationChannelId: 'diafon_fg',
      initialNotificationTitle: 'Diafon',
      initialNotificationContent: 'Cagrilara hazir',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
  await service.startService();
}
