import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../core/core.dart';
import '../models/user_model.dart';

class AuthService {
  static final String _userKey = MyConstants.userData;
  static final String _tokenKey = MyConstants.token;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Save user info and token securely
  Future<void> saveUserData(Map<String, dynamic> user, {String? token}) async {
    final userJson = jsonEncode(user);
    await _storage.write(key: _userKey, value: userJson);
    if (token != null) await _storage.write(key: _tokenKey, value: token);
  }

  /// Get user data as Map
  Future<UserModel?> getUserData() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      final map = jsonDecode(userJson);
      return UserModel.fromJson(map);
    }
    return null;
  }

  /// Get auth token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Logout user (clear secure storage)
  Future<void> logout() async {
    await _storage.deleteAll();
    // await firebaseSignOut();
  }
}
