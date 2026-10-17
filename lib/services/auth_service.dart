import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;

  AuthService({FirebaseAuth? auth}) {
    try {
      _auth = auth ?? FirebaseAuth.instance;
      _auth?.authStateChanges().listen((User? user) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('AuthService: Running in offline/test mode without Firebase: $e');
    }
  }

  User? get currentUser => _auth?.currentUser;
  bool get isAuthenticated => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
  String? get userEmail => currentUser?.email;
  String get displayName =>
      currentUser?.displayName ??
      currentUser?.email ??
      (isAnonymous ? 'Guest User' : 'Not signed in');

  /// Get current Firebase JWT token for authenticating against Cloudflare Worker API
  Future<String?> getIdToken() async {
    if (_auth == null || currentUser == null) return null;
    try {
      return await currentUser?.getIdToken();
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  /// Sign in anonymously for instant zero-friction guest access
  Future<UserCredential?> signInAnonymously() async {
    if (_auth == null) {
      throw Exception('Firebase is not initialized.');
    }
    try {
      final credential = await _auth!.signInAnonymously();
      notifyListeners();
      return credential;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  /// Sign in with Email & Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    if (_auth == null) {
      throw Exception('Firebase is not initialized.');
    }
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
      return credential;
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      rethrow;
    }
  }

  /// Create a new account with Email & Password
  Future<UserCredential> registerWithEmail(String email, String password) async {
    if (_auth == null) {
      throw Exception('Firebase is not initialized.');
    }
    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
      return credential;
    } catch (e) {
      debugPrint('Error registering user: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (_auth == null) return;
    try {
      await _auth!.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
