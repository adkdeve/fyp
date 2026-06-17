// ignore_for_file: avoid_print
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/violation_model.dart';

/// Device-level local notifications. Naye safety violation par phone notification
/// dikhata hai (FCM/server push ki zaroorat nahi — purely client-side).
///
/// Do channels: ek sound ke saath, ek silent — kyunki Android 8+ par sound
/// channel se control hota hai (per-notification nahi). Sound toggle isi se kaam karta hai.
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  static NotificationService get to => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _soundChannelId = 'violations_channel';
  static const String _silentChannelId = 'violations_silent';
  static const String _channelName = 'Safety Violations';
  static const String _silentChannelName = 'Safety Violations (Silent)';
  static const String _channelDesc = 'Alerts for newly detected safety violations';

  Future<void> init() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _plugin.initialize(settings);

      // Android 13+ runtime notification permission
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      // Channels (Android 8+) — ek sound, ek silent
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _soundChannelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _silentChannelId,
          _silentChannelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
        ),
      );

      _ready = true;
    } catch (e) {
      print('NotificationService init error: $e');
    }
  }

  /// Naye violation ke liye notification. [playSound] sound channel choose karta hai.
  Future<void> showViolation(ViolationModel v, {bool playSound = true}) async {
    if (!_ready) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        playSound ? _soundChannelId : _silentChannelId,
        playSound ? _channelName : _silentChannelName,
        channelDescription: _channelDesc,
        importance: playSound ? Importance.max : Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: playSound,
        enableVibration: playSound,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentSound: playSound),
      );

      final sev = v.severity.name.isEmpty
          ? ''
          : '${v.severity.name[0].toUpperCase()}${v.severity.name.substring(1)} • ';
      final title = '$sev${v.type.name} Violation Detected';
      final body = v.zone.isNotEmpty ? '${v.zone} — ${v.description}' : v.description;

      await _plugin.show(v.id.hashCode, title, body, details);
    } catch (e) {
      print('NotificationService show error: $e');
    }
  }

  /// Generic notification helper.
  Future<void> show(String title, String body, {bool playSound = true}) async {
    if (!_ready) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          playSound ? _soundChannelId : _silentChannelId,
          playSound ? _channelName : _silentChannelName,
          channelDescription: _channelDesc,
          importance: playSound ? Importance.max : Importance.high,
          priority: Priority.high,
          playSound: playSound,
          enableVibration: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      );
      await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
    } catch (e) {
      print('NotificationService show error: $e');
    }
  }
}
