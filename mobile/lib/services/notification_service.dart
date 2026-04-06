import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      'alerts_channel',
      'Alerts',
      channelDescription: 'Network alerts and service issues',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }
}
