import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'connectivity_service.dart';

/// AI Detection Controls API client — mirrors the web `mlApi`.
///
/// Backend endpoints (preferred over hitting the ML service directly, so that
/// preferences survive ML restarts and reach every camera worker):
///   GET  /ai-controls/status   -> { active_models: { helmet, firesmoke } }
///   POST /ai-controls/toggle   -> { model, active }
///   POST /ai-controls/bulk     -> { models: {...} }
///
/// Note: backend sirf `helmet` (PPE) aur `firesmoke` (Fire & Smoke) support
/// karta hai. Web ka SafeZone/Face ML service ko direct call karta hai jo
/// mobile tunnel se reachable nahi, isliye yahan PPE + Fire ko handle kar rahe hain.
class AiControlsService {
  static const String _prefsKey = 'ml_detection_prefs';

  String get _base => '${AppConfig.baseUrl}ai-controls';

  /// Net available hai ya nahi — offline mein bekaar HTTP calls avoid karne ke liye.
  bool get _online =>
      !Get.isRegistered<ConnectivityService>() || ConnectivityService.to.online;

  // ── Local preferences (shared_preferences, web localStorage ke barabar) ────
  Future<DetectionPrefs> loadPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return DetectionPrefs(
          ppe: map['ppe'] == true,
          fire: map['fire'] == true,
        );
      }
    } catch (_) {}
    return const DetectionPrefs(ppe: false, fire: false);
  }

  Future<void> savePrefs(DetectionPrefs prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode({'ppe': prefs.ppe, 'fire': prefs.fire}));
  }

  // ── Backend calls ──────────────────────────────────────────────────────────

  /// Returns the backend's active model map, or null if unreachable.
  /// Map keys: `helmet`, `firesmoke`.
  Future<Map<String, bool>?> getStatus() async {
    if (!_online) return null;
    try {
      final res = await http
          .get(Uri.parse('$_base/status'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final am = (data['active_models'] as Map?) ?? {};
        return {
          'helmet': am['helmet'] == true,
          'firesmoke': am['firesmoke'] == true,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Toggle PPE (helmet) detection. Returns true on success.
  Future<bool> togglePpe(bool active) => _toggle('helmet', active);

  /// Toggle Fire & Smoke (firesmoke) detection. Returns true on success.
  Future<bool> toggleFire(bool active) => _toggle('firesmoke', active);

  Future<bool> _toggle(String model, bool active) async {
    if (!_online) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$_base/toggle'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': model, 'active': active}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Re-apply saved prefs to the backend (call on Settings open, like web).
  Future<void> applyPrefs(DetectionPrefs prefs) async {
    if (!_online) return;
    try {
      await http
          .post(
            Uri.parse('$_base/bulk'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'models': {'helmet': prefs.ppe, 'firesmoke': prefs.fire},
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

class DetectionPrefs {
  final bool ppe;
  final bool fire;
  const DetectionPrefs({required this.ppe, required this.fire});

  DetectionPrefs copyWith({bool? ppe, bool? fire}) =>
      DetectionPrefs(ppe: ppe ?? this.ppe, fire: fire ?? this.fire);
}
