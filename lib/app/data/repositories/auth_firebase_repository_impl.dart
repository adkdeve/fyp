import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import 'auth_firebase_repository.dart';

class AuthFirebaseRepositoryImpl implements AuthFirebaseRepository {
  final FirebaseAuthService _authService = FirebaseAuthService();

  // Firebase methods
  @override
  Future<User?> firebaseSignIn(String email, String password) =>
      _authService.firebaseSignIn(email, password);

  @override
  Future<User?> firebaseRegister(String email, String password) =>
      _authService.firebaseRegister(email, password);

  @override
  Future<void> firebaseResetPassword(String email) =>
      _authService.firebaseResetPassword(email);

  @override
  Future<void> firebaseSignOut() => _authService.firebaseSignOut();

  @override
  User? get firebaseCurrentUser => _authService.firebaseCurrentUser;

  @override
  Stream<User?> get firebaseAuthStateChanges =>
      _authService.firebaseAuthStateChanges;
}
