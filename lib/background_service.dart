import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

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

// Zil (doorbell) kanalları - her zil sesi için ayrı kanal (Android sesi kanal bazlı sabitler)
  final androidImpl = fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  for (int t = 1; t <= 5; t++) {
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(
        'doorbell_tone$t',
        'Kapı Zili $t',
        description: 'Ziyaretçi zil çaldığında bildirim (ton $t)',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('tone$t'),
        playSound: true,
      ),
    );
  }


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

Future<void> showDoorbellNotification(String visitorName, String buildingName) async {
  final fln = FlutterLocalNotificationsPlugin();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await fln.initialize(settings: initSettings);
  // Kullanıcının seçtiği zil sesi (tone1..tone5)
  final tone = await ApiService.getDoorbellSound();
  final androidDetails = AndroidNotificationDetails(
    'doorbell_$tone',
    'Kapı Zili',
    channelDescription: 'Ziyaretçi zil çaldığında bildirim',
    importance: Importance.high,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound(tone),
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );
  await fln.show(
    id: 9001,
    title: '🔔 Kapıda ziyaretçi var',
    body: '$visitorName zil çaldı',
    notificationDetails: NotificationDetails(android: androidDetails),
  );
}
