import '../models/user_model.dart';

abstract class AuthRepository {
  // Secure storage methods
  Future<void> saveUserData(Map<String, dynamic> user, String token);
  Future<UserModel?> getUserData();
  Future<String?> getToken();
  Future<bool> isLoggedIn();
  Future<void> logout();
}
