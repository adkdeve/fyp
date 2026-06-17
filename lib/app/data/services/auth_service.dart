import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../core/core.dart';
import '../models/user_model.dart';

class AuthService {
  static final String _userKey = MyConstants.userData;
  static final String _tokenKey = MyConstants.token;
  static const String _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Save user info and token securely
  Future<void> saveUserData(Map<String, dynamic> user, {String? token}) async {
    final normalized = _normalizeUserMap(user);
    final userJson = jsonEncode(normalized);
    await _storage.write(key: _userKey, value: userJson);
    if (token != null) await _storage.write(key: _tokenKey, value: token);
  }

  Map<String, dynamic> _normalizeUserMap(Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);
    if (normalized.containsKey('login_id') && !normalized.containsKey('loginId')) {
      normalized['loginId'] = normalized['login_id']?.toString();
    }
    if (normalized.containsKey('loginId') && !normalized.containsKey('login_id')) {
      normalized['login_id'] = normalized['loginId']?.toString();
    }

    if (normalized.containsKey('site_ids') && !normalized.containsKey('siteIds')) {
      normalized['siteIds'] = _parseStringList(normalized['site_ids']);
    }
    if (normalized.containsKey('siteIds') && !normalized.containsKey('site_ids')) {
      normalized['site_ids'] = _parseStringList(normalized['siteIds']);
    }

    if (normalized.containsKey('id')) {
      normalized['id'] = normalized['id']?.toString();
    }
    if (normalized.containsKey('uid') && !normalized.containsKey('id')) {
      normalized['id'] = normalized['uid']?.toString();
      normalized['uid'] = normalized['uid']?.toString();
    }
    return normalized;
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is! List) return null;
    return value.where((item) => item != null).map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }

  Future<String?> getUserId() async {
    final user = await getUserData();
    if (user?.id.isNotEmpty == true) return user!.id;
    final raw = await getRawUserData();
    if (raw == null) return null;
    if (raw['id'] != null) return raw['id'].toString();
    if (raw['uid'] != null) return raw['uid'].toString();
    return null;
  }

  Future<Map<String, dynamic>?> getSiteOfficerSession() async {
    final raw = await getRawUserData();
    if (raw == null) return null;
    final id = await getUserId();
    if (id == null || id.isEmpty) return null;

    final user = await getUserData();
    final siteIds = user?.siteIds ?? _parseStringList(raw['siteIds'] ?? raw['site_ids']);

    return {
      'id': id,
      'name': user?.name ?? raw['name']?.toString() ?? '${raw['first_name'] ?? ''} ${raw['last_name'] ?? ''}'.trim(),
      'email': user?.email ?? raw['email']?.toString() ?? '',
      'phone': raw['phone']?.toString() ?? raw['phone_number']?.toString() ?? '',
      'loginId': raw['loginId']?.toString() ?? raw['login_id']?.toString(),
      'siteIds': siteIds ?? <String>[],
      'status': raw['status']?.toString() ?? 'inactive',
    };
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getOfficerDocument(String uid) async {
    return FirebaseFirestore.instance.collection('officers').doc(uid).get();
  }

  Future<Map<String, dynamic>?> syncUserSession() async {
    final storedSession = await getSiteOfficerSession();
    if (storedSession == null) return null;

    final doc = await _getOfficerDocument(storedSession['id'].toString());
    if (!doc.exists) {
      await logout();
      return null;
    }

    final fresh = doc.data() ?? {};
    fresh['id'] = doc.id;
    fresh.remove('password');

    final status = fresh['status']?.toString().toLowerCase();
    final freshSiteIds = _parseStringList(fresh['siteIds'] ?? fresh['site_ids']);
    if (status != 'active' || freshSiteIds == null || freshSiteIds.isEmpty) {
      await logout();
      return null;
    }

    final storedSiteIds = _parseStringList(storedSession['siteIds']);
    final mergedSiteIds = <String>{if (storedSiteIds != null) ...storedSiteIds, ...freshSiteIds}.toList();
    fresh['siteIds'] = mergedSiteIds;
    fresh['site_ids'] = mergedSiteIds;

    await saveUserData(fresh);
    return fresh;
  }

  Future<Map<String, dynamic>?> refreshUserData() async {
    final uid = await getUserId();
    if (uid == null || uid.isEmpty) return null;
    final doc = await _getOfficerDocument(uid);
    if (!doc.exists) return null;

    final result = doc.data() ?? {};
    result['id'] = doc.id;
    result.remove('password');
    await saveUserData(result);
    return result;
  }

  /// Save access + refresh tokens (called after login/refresh)
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  /// Get user data as UserModel
  Future<UserModel?> getUserData() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      final map = jsonDecode(userJson);
      return UserModel.fromJson(map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getRawUserData() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      final map = jsonDecode(userJson);
      return map is Map<String, dynamic> ? map : Map<String, dynamic>.from(map);
    }
    return null;
  }

  Future<List<String>?> getUserSiteIds() async {
    final user = await getUserData();
    if (user?.siteIds?.isNotEmpty == true) return user!.siteIds;

    final raw = await getRawUserData();
    return _parseStringList(raw?['siteIds'] ?? raw?['site_ids']);
  }

  /// Get access token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout user (clear secure storage)
  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
