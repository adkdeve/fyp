import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Sign In with Email & Password (Firebase)
  Future<User?> firebaseSignIn(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Register with Email & Password (Firebase)
  Future<User?> firebaseRegister(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Reset Password (Firebase)
  Future<void> firebaseResetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Firebase sign out
  Future<void> firebaseSignOut() async {
    await _firebaseAuth.signOut();
  }

  /// Get Firebase current user
  User? get firebaseCurrentUser => _firebaseAuth.currentUser;

  /// Firebase auth state changes
  Stream<User?> get firebaseAuthStateChanges =>
      _firebaseAuth.authStateChanges();
}
