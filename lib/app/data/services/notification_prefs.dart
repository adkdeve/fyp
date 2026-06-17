import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Notification preferences ka central source of truth (in-memory + persisted).
/// Settings inhe update karta hai, MainController naye violation par inhe read
/// karta hai — taake push / pop-up / sound teeno toggles actually kaam karein.
class NotificationPrefs {
  NotificationPrefs._();
  static final NotificationPrefs to = NotificationPrefs._();

  static const String _key = 'site_notif_prefs';

  /// In-app pop-up (snackbar) on new violation.
  bool alertPopups = true;

  /// Sound/vibration ke saath alert.
  bool soundAlerts = false;

  /// Device-level push notification.
  bool pushNotifications = true;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        alertPopups = m['alerts'] != false; // default true
        soundAlerts = m['sound'] == true; // default false
        pushNotifications = m['push'] != false; // default true
      }
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _key,
        jsonEncode({
          'alerts': alertPopups,
          'sound': soundAlerts,
          'push': pushNotifications,
        }),
      );
    } catch (_) {}
  }
}
