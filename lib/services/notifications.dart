import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    const a = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: a));
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> schedule(
      int id, String title, String body, DateTime date) async {
    if (kIsWeb) return;
    final when = tz.TZDateTime.from(date, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    await plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'autocare', 'AutoCare Reminders',
                importance: Importance.high, priority: Priority.high)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'autocare');
  }

  static Future<void> show(String title, String body) async {
    if (kIsWeb) return;
    await plugin.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      const NotificationDetails(
          android: AndroidNotificationDetails('autocare', 'AutoCare Reminders',
              importance: Importance.high, priority: Priority.high)));
  }
}
