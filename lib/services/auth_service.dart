import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  Future<void>? _googleReady;
  StreamSubscription<User?>? _subscription;
  String? _googleProfileUid;
  Map<String, dynamic>? _googleProfile;

  /// Defaults only: saved About Me details always take precedence.
  Map<String, String> get googleProfileDefaults {
    final user = currentUser;
    if (user == null) return const {};
    final google = user.providerData
        .where((p) => p.providerId == 'google.com')
        .firstOrNull;
    if (google == null) return const {};
    final raw = _googleProfileUid == user.uid ? _googleProfile : null;
    String value(Object? v) => v is String ? v.trim() : '';
    final name = value(google.displayName ?? user.displayName);
    final given = value(raw?['given_name']);
    final family = value(raw?['family_name']);
    // Keep an unstructured display name intact rather than guessing which
    // words are family names. The user can split it while reviewing setup.
    return {
      'firstName': given.isNotEmpty ? given : (family.isNotEmpty ? '' : name),
      'lastName': family,
      'email': value(google.email ?? user.email),
      'phone': value(google.phoneNumber ?? user.phoneNumber),
      'photoURL': value(google.photoURL ?? user.photoURL),
    };
  }

  AuthService({FirebaseAuth? auth}) {
    try {
      _auth = auth ?? FirebaseAuth.instance;
      _subscription = _auth?.authStateChanges().listen((User? user) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint(
        'AuthService: Running in offline/test mode without Firebase: $e',
      );
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
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    if (_auth == null) {
      throw Exception('Firebase is not initialized.');
    }
    try {
      final credential = isAnonymous
          ? await currentUser!.linkWithCredential(
              EmailAuthProvider.credential(
                email: email.trim(),
                password: password,
              ),
            )
          : await _auth!.createUserWithEmailAndPassword(
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

  Future<UserCredential?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Sign-in is unavailable. Please reopen the app.');
    }
    UserCredential result;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      result = isAnonymous
          ? await currentUser!.linkWithPopup(provider)
          : await auth.signInWithPopup(provider);
    } else {
      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS) {
        throw UnsupportedError('Use email sign-in on this device.');
      }
      _googleReady ??= GoogleSignIn.instance.initialize();
      await _googleReady;
      try {
        final account = await GoogleSignIn.instance.authenticate();
        final token = account.authentication.idToken;
        if (token == null) {
          throw StateError(
            'Google could not complete sign-in. Please try again.',
          );
        }
        final credential = GoogleAuthProvider.credential(idToken: token);
        result = isAnonymous
            ? await currentUser!.linkWithCredential(credential)
            : await auth.signInWithCredential(credential);
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return null;
        rethrow;
      }
    }
    _googleProfileUid = result.user?.uid;
    _googleProfile = result.additionalUserInfo?.profile;
    notifyListeners();
    return result;
  }

  Future<void> sendPasswordReset(String email) async {
    if (_auth == null) {
      throw StateError('Sign-in is unavailable. Please reopen the app.');
    }
    await _auth!.sendPasswordResetEmail(email: email.trim());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get usesPassword =>
      currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  Future<bool> reauthenticateForDeletion(String password) async {
    final user = currentUser;
    if (user == null) throw StateError('Please sign in first.');
    if (usesPassword) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else if (user.providerData.any((p) => p.providerId == 'google.com')) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        _googleReady ??= GoogleSignIn.instance.initialize();
        await _googleReady;
        try {
          final account = await GoogleSignIn.instance.authenticate();
          final token = account.authentication.idToken;
          if (token == null) {
            throw StateError('Google sign-in did not complete.');
          }
          await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(idToken: token),
          );
        } on GoogleSignInException catch (error) {
          if (error.code == GoogleSignInExceptionCode.canceled) return false;
          rethrow;
        }
      }
    } else if (!user.isAnonymous) {
      throw StateError(
        'Sign out and sign in again before deleting this account.',
      );
    }
    if (currentUser?.uid != user.uid) throw StateError('Account changed.');
    await user.getIdToken(true);
    return true;
  }

  /// Sign out
  Future<void> signOut() async {
    if (_auth == null) return;
    try {
      await _auth!.signOut();
      _googleProfileUid = null;
      _googleProfile = null;
      if (!kIsWeb && _googleReady != null) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {
          /* Firebase session is already signed out. */
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
