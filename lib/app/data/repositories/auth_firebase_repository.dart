import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthFirebaseRepository {
  // Firebase methods
  Future<User?> firebaseSignIn(String email, String password);
  Future<User?> firebaseRegister(String email, String password);
  Future<void> firebaseResetPassword(String email);
  Future<void> firebaseSignOut();
  User? get firebaseCurrentUser;
  Stream<User?> get firebaseAuthStateChanges;
}
