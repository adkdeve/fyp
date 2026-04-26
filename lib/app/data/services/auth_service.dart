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
    final userJson = jsonEncode(user);
    await _storage.write(key: _userKey, value: userJson);
    if (token != null) await _storage.write(key: _tokenKey, value: token);
  }

  /// Save access + refresh tokens (called after login/refresh)
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
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
