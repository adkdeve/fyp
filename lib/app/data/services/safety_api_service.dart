import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
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
    var res = await http.get(uri, headers: await _headers())
        .timeout(AppConfig.apiTimeout);
    if (res.statusCode == 401 && await tryRefreshToken()) {
      res = await http.get(uri, headers: await _headers())
          .timeout(AppConfig.apiTimeout);
    }
    return _handle(res);
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
    final body = jsonDecode(res.body);
    throw body['detail'] ?? 'Request failed (${res.statusCode})';
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

  // ── Cameras ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getCameras({bool enabledOnly = false}) async {
    return await _get(ApisUrl.cameras,
        query: enabledOnly ? {'enabled_only': 'true'} : null);
  }

  Future<Map<String, dynamic>> createCamera(Map<String, dynamic> data) async {
    return await _post(ApisUrl.cameras, data);
  }

  // ── Violations ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getViolations({
    String? status,
    String? severity,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final q = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
      if (type != null) 'type': type,
    };
    return await _get(ApisUrl.violations, query: q);
  }

  Future<Map<String, dynamic>> resolveViolation(
      int id, String status, {String? notes}) async {
    return await _patch(ApisUrl.resolveViolation(id), {
      'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  // ── Alerts ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAlerts({bool unreadOnly = false}) async {
    return await _get(ApisUrl.alerts,
        query: unreadOnly ? {'unread_only': 'true'} : null);
  }

  Future<void> markAllAlertsRead() async {
    await _patch(ApisUrl.markAllRead, {});
  }

  // ── Analytics ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSummary({int days = 7}) async {
    return await _get(ApisUrl.analyticsSummary,
        query: {'days': days.toString()});
  }

  Future<List<dynamic>> getByType({int days = 7}) async {
    return await _get(ApisUrl.analyticsByType,
        query: {'days': days.toString()});
  }

  Future<List<dynamic>> getBySeverity({int days = 7}) async {
    return await _get(ApisUrl.analyticsBySeverity,
        query: {'days': days.toString()});
  }

  Future<List<dynamic>> getTrend({int days = 7}) async {
    return await _get(ApisUrl.analyticsTrend, query: {'days': days.toString()});
  }

  Future<List<dynamic>> getByCamera({int days = 7}) async {
    return await _get(ApisUrl.analyticsByCamera,
        query: {'days': days.toString()});
  }
}
