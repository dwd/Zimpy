import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    final linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );
    await _plugin.initialize(settings);
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  Future<void> showMessage({
    required int id,
    required String title,
    required String body,
    String? tag,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    final androidDetails = AndroidNotificationDetails(
      'wimsy_messages',
      'Messages',
      channelDescription: 'Incoming chat messages',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      tag: tag,
    );
    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );
    await _plugin.show(id, title, body, details);
  }

  bool get isInitialized => _initialized;
}
