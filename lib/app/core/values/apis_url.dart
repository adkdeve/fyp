import '../core.dart';

class ApisUrl {
  // ── Auth ────────────────────────────────────────────────────────────────
  static const String login = '${AppConfig.baseUrl}auth/login';
  static const String register = '${AppConfig.baseUrl}auth/register';
  static const String refresh = '${AppConfig.baseUrl}auth/refresh';
  static const String me = '${AppConfig.baseUrl}auth/me';
  static const String avatar = '${AppConfig.baseUrl}auth/me/avatar';
  static const String changePassword = '${AppConfig.baseUrl}auth/me/password';

  // ── Cameras ─────────────────────────────────────────────────────────────
  static const String cameras = '${AppConfig.baseUrl}cameras';
  static String cameraById(int id) => '${AppConfig.baseUrl}cameras/$id';

  // ── Violations ──────────────────────────────────────────────────────────
  static const String violations = '${AppConfig.baseUrl}violations';
  static String violationById(int id) => '${AppConfig.baseUrl}violations/$id';
  static String resolveViolation(int id) =>
      '${AppConfig.baseUrl}violations/$id/resolve';

  // ── Alerts ──────────────────────────────────────────────────────────────
  static const String alerts = '${AppConfig.baseUrl}alerts';
  static String markAlertRead(int id) => '${AppConfig.baseUrl}alerts/$id/read';
  static const String markAllRead = '${AppConfig.baseUrl}alerts/read-all';

  // ── Analytics ───────────────────────────────────────────────────────────
  static const String analyticsSummary =
      '${AppConfig.baseUrl}analytics/summary';
  static const String analyticsByType = '${AppConfig.baseUrl}analytics/by-type';
  static const String analyticsBySeverity =
      '${AppConfig.baseUrl}analytics/by-severity';
  static const String analyticsTrend = '${AppConfig.baseUrl}analytics/trend';
  static const String analyticsByCamera =
      '${AppConfig.baseUrl}analytics/by-camera';
  static const String analyticsExport = '${AppConfig.baseUrl}analytics/export';
  static const String violationsExport =
      '${AppConfig.baseUrl}violations/export';

  // Settings
  static const String notificationSettings =
      '${AppConfig.baseUrl}settings/notifications';

  // Stream
  static String streamFrame(int cameraId) =>
      '${AppConfig.baseUrl}stream/$cameraId/frame';
  static String streamSnapshot(int cameraId) =>
      '${AppConfig.baseUrl}stream/$cameraId/snapshot';

  // ── WebSocket ────────────────────────────────────────────────────────────
  static String wsAlerts(String token) => '${AppConfig.wsBaseUrl}?token=$token';
}
