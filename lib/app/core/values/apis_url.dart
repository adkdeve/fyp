import '../core.dart';

class ApisUrl {
  // ── Auth ────────────────────────────────────────────────────────────────
  static String get login => '${AppConfig.baseUrl}auth/login';
  static String get register => '${AppConfig.baseUrl}auth/register';
  static String get refresh => '${AppConfig.baseUrl}auth/refresh';
  static String get me => '${AppConfig.baseUrl}auth/me';
  static String get avatar => '${AppConfig.baseUrl}auth/me/avatar';
  static String get changePassword => '${AppConfig.baseUrl}auth/me/password';

  // ── Cameras ─────────────────────────────────────────────────────────────
  static String get cameras => '${AppConfig.baseUrl}cameras';
  static String cameraById(int id) => '${AppConfig.baseUrl}cameras/$id';

  // ── Violations ──────────────────────────────────────────────────────────
  static String get violations => '${AppConfig.baseUrl}violations';
  static String violationById(int id) => '${AppConfig.baseUrl}violations/$id';
  static String resolveViolation(int id) => '${AppConfig.baseUrl}violations/$id/resolve';

  // ── Alerts ──────────────────────────────────────────────────────────────
  static String get alerts => '${AppConfig.baseUrl}alerts';
  static String markAlertRead(int id) => '${AppConfig.baseUrl}alerts/$id/read';
  static String get markAllRead => '${AppConfig.baseUrl}alerts/read-all';

  // ── Analytics ───────────────────────────────────────────────────────────
  static String get analyticsSummary => '${AppConfig.baseUrl}analytics/summary';
  static String get analyticsByType => '${AppConfig.baseUrl}analytics/by-type';
  static String get analyticsBySeverity => '${AppConfig.baseUrl}analytics/by-severity';
  static String get analyticsTrend => '${AppConfig.baseUrl}analytics/trend';
  static String get analyticsByCamera => '${AppConfig.baseUrl}analytics/by-camera';
  static String get analyticsExport => '${AppConfig.baseUrl}analytics/export';
  static String get violationsExport => '${AppConfig.baseUrl}violations/export';

  // Settings
  static String get notificationSettings => '${AppConfig.baseUrl}settings/notifications';

  // Stream
  static String streamFrame(dynamic cameraId) => '${AppConfig.baseUrl}stream/$cameraId/frame';
  static String streamSnapshot(dynamic cameraId) => '${AppConfig.baseUrl}stream/$cameraId/snapshot';

  // ── WebSocket ────────────────────────────────────────────────────────────
  static String wsAlerts(String token) => '${AppConfig.wsBaseUrl}?token=$token';
}
