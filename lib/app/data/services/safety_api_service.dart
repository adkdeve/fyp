import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../../../app/core/config/app_config.dart';
import '../../../app/core/values/apis_url.dart';
import 'auth_service.dart';

/// Centralised API client for all safety backend calls.
class SafetyApiService {
  static SafetyApiService get to => Get.find();

  final AuthService _auth = Get.find<AuthService>();

  // Prevent concurrent refresh attempts
  bool _isRefreshing = false;

  // ── Token Refresh ─────────────────────────────────────────────────────────

  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns true if refresh succeeded and new tokens were saved.
  Future<bool> tryRefreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refreshToken = await _auth.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final res = await http
          .post(
            Uri.parse(ApisUrl.refresh),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(AppConfig.apiTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await _auth.saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String?,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET with automatic 401 → refresh → retry logic.
  Future<dynamic> _get(String url, {Map<String, String>? query}) async {
    final uri = Uri.parse(url).replace(queryParameters: query);
    var res = await http
        .get(uri, headers: await _headers())
        .timeout(AppConfig.apiTimeout);
    if (res.statusCode == 401 && await tryRefreshToken()) {
      res = await http
          .get(uri, headers: await _headers())
          .timeout(AppConfig.apiTimeout);
    }
    return _handle(res);
  }

  Future<Uint8List> _download(String url, {Map<String, String>? query}) async {
    final uri = Uri.parse(url).replace(queryParameters: query);
    var res = await http
        .get(uri, headers: await _headers())
        .timeout(AppConfig.apiTimeout);
    if (res.statusCode == 401 && await tryRefreshToken()) {
      res = await http
          .get(uri, headers: await _headers())
          .timeout(AppConfig.apiTimeout);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    _handle(res);
    return Uint8List(0);
  }

  /// POST with automatic 401 → refresh → retry logic.
  Future<dynamic> _post(String url, Map<String, dynamic> body) async {
    final encoded = jsonEncode(body);
    var res = await http
        .post(Uri.parse(url), headers: await _headers(), body: encoded)
        .timeout(AppConfig.apiTimeout);
    if (res.statusCode == 401 && await tryRefreshToken()) {
      res = await http
          .post(Uri.parse(url), headers: await _headers(), body: encoded)
          .timeout(AppConfig.apiTimeout);
    }
    return _handle(res);
  }

  /// PATCH with automatic 401 → refresh → retry logic.
  Future<dynamic> _patch(String url, Map<String, dynamic> body) async {
    final encoded = jsonEncode(body);
    var res = await http
        .patch(Uri.parse(url), headers: await _headers(), body: encoded)
        .timeout(AppConfig.apiTimeout);
    if (res.statusCode == 401 && await tryRefreshToken()) {
      res = await http
          .patch(Uri.parse(url), headers: await _headers(), body: encoded)
          .timeout(AppConfig.apiTimeout);
    }
    return _handle(res);
  }

  Future<dynamic> _delete(String url) async {
    var res = await http
        .delete(Uri.parse(url), headers: await _headers())
        .timeout(AppConfig.apiTimeout);
    if (res.statusCode == 401 && await tryRefreshToken()) {
      res = await http
          .delete(Uri.parse(url), headers: await _headers())
          .timeout(AppConfig.apiTimeout);
    }
    return _handle(res);
  }

  Future<dynamic> _multipartFile(
    String url,
    String fieldName,
    File file,
  ) async {
    final filename = file.path.split(RegExp(r'[\\/]')).last;
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
    final mimeParts = mimeType.split('/');
    final contentType = mimeParts.length == 2
        ? MediaType(mimeParts[0], mimeParts[1])
        : MediaType('image', 'jpeg');

    Future<http.StreamedResponse> send() async {
      final req = http.MultipartRequest('POST', Uri.parse(url));
      final token = await _auth.getToken();
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';
      req.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          filename: filename,
          contentType: contentType,
        ),
      );
      return req.send().timeout(AppConfig.apiTimeout);
    }

    var streamed = await send();
    var res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401 && await tryRefreshToken()) {
      streamed = await send();
      res = await http.Response.fromStream(streamed);
    }
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode == 401) {
      // Refresh already attempted (or no refresh token) — force re-login
      _auth.logout();
      Get.offAllNamed('/login');
      throw 'Session expired. Please log in again.';
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    dynamic detail;
    try {
      final body = jsonDecode(res.body);
      detail = body['detail'];
    } catch (_) {}
    throw detail ?? 'Request failed (${res.statusCode})';
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _post(ApisUrl.login, {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> getMe() async {
    return await _get(ApisUrl.me);
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    return await _patch(ApisUrl.me, data);
  }

  Future<Map<String, dynamic>> uploadAvatar(File file) async {
    return await _multipartFile(ApisUrl.avatar, 'avatar', file);
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _patch(ApisUrl.changePassword, {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> deleteAccount() async {
    await _delete(ApisUrl.me);
  }

  // ── Cameras ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getCameras({
    bool enabledOnly = false,
    bool? enabled,
    String? status,
    String? q,
  }) async {
    final raw = await _get(
      ApisUrl.cameras,
      query: {
        if (enabledOnly) 'enabled_only': 'true',
        if (enabled != null) 'enabled': enabled.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );

    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      for (final key in ['items', 'results', 'data', 'cameras']) {
        final value = raw[key];
        if (value is List) return value;
      }
    }
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> createCamera(Map<String, dynamic> data) async {
    return await _post(ApisUrl.cameras, data);
  }

  Future<Map<String, dynamic>> updateCamera(
    int id,
    Map<String, dynamic> data,
  ) async {
    return await _patch(ApisUrl.cameraById(id), data);
  }

  // ── Violations ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getViolations({
    String? q,
    String? status,
    String? severity,
    String? type,
    int? cameraId,
    bool enabledOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (enabledOnly) 'enabled_only': 'true',
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
      if (type != null) 'type': type,
      if (cameraId != null) 'camera_id': cameraId.toString(),
    };
    return await _get(ApisUrl.violations, query: query);
  }

  Future<Map<String, dynamic>> resolveViolation(
    int id,
    String status, {
    String? notes,
  }) async {
    return await _patch(ApisUrl.resolveViolation(id), {
      'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  // ── Alerts ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAlerts({
    bool unreadOnly = false,
    bool enabledOnly = false,
    String? q,
    String? severity,
    int limit = 50,
  }) async {
    return await _get(
      ApisUrl.alerts,
      query: {
        'limit': limit.toString(),
        if (unreadOnly) 'unread_only': 'true',
        if (enabledOnly) 'enabled_only': 'true',
        if (q != null && q.isNotEmpty) 'q': q,
        if (severity != null && severity.isNotEmpty) 'severity': severity,
      },
    );
  }

  Future<void> markAllAlertsRead() async {
    await _patch(ApisUrl.markAllRead, {});
  }

  // ── Analytics ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSummary({int days = 7}) async {
    return await _get(
      ApisUrl.analyticsSummary,
      query: {'days': days.toString()},
    );
  }

  Future<List<dynamic>> getByType({int days = 7}) async {
    return await _get(
      ApisUrl.analyticsByType,
      query: {'days': days.toString()},
    );
  }

  Future<List<dynamic>> getBySeverity({int days = 7}) async {
    return await _get(
      ApisUrl.analyticsBySeverity,
      query: {'days': days.toString()},
    );
  }

  Future<List<dynamic>> getTrend({int days = 7}) async {
    return await _get(ApisUrl.analyticsTrend, query: {'days': days.toString()});
  }

  Future<List<dynamic>> getByCamera({int days = 7}) async {
    return await _get(
      ApisUrl.analyticsByCamera,
      query: {'days': days.toString()},
    );
  }

  Future<Map<String, dynamic>> getNotificationSettings() async {
    return await _get(ApisUrl.notificationSettings);
  }

  Future<Map<String, dynamic>> updateNotificationSettings(
    Map<String, dynamic> data,
  ) async {
    return await _patch(ApisUrl.notificationSettings, data);
  }

  Future<Map<String, dynamic>> takeSnapshot(int cameraId) async {
    return await _post(ApisUrl.streamSnapshot(cameraId), {});
  }

  Future<Uint8List> exportViolations({
    String? q,
    String? type,
    String? severity,
    String? status,
  }) async {
    return await _download(
      ApisUrl.violationsExport,
      query: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (type != null && type.isNotEmpty) 'type': type,
        if (severity != null && severity.isNotEmpty) 'severity': severity,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  Future<Uint8List> exportAnalytics({int days = 7}) async {
    return await _download(
      ApisUrl.analyticsExport,
      query: {'days': days.toString()},
    );
  }
}
