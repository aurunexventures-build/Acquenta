import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/screens/auth_screen.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/providers/account_profile_provider.dart';
import 'package:contact_card_builder/screens/account_profile_screen.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/theme/metcue_theme.dart';

class TestCredential extends Fake implements UserCredential {}

class LoginUser extends Fake implements User {
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => const [];
  final String id;
  LoginUser(this.id);
  @override
  String get uid => id;
  @override
  bool get isAnonymous => false;
  @override
  String get email => '$id@example.com';
  @override
  String get displayName => id;
}

class LoginAuth extends AuthService {
  User? user;
  String? emailUsed, passwordUsed, resetEmail;
  int googleCalls = 0, registerCalls = 0;
  bool fail = false;
  @override
  User? get currentUser => user;
  @override
  Future<String?> getIdToken() async => null;
  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    emailUsed = email.trim();
    passwordUsed = password;
    if (fail) throw FirebaseAuthException(code: 'invalid-credential');
    return TestCredential();
  }

  @override
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    registerCalls++;
    emailUsed = email.trim();
    passwordUsed = password;
    return TestCredential();
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    googleCalls++;
    return null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email.trim();
  }

  void login(String uid) {
    user = LoginUser(uid);
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    user = null;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [360.0, 390.0, 1000.0]) {
    testWidgets('auth validation, Google action and keyboard at $width', (
      tester,
    ) async {
      final auth = LoginAuth();
      addTearDown(auth.dispose);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            theme: MetCueTheme.light,
            home: AuthScreen(onContinueOffline: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(auth.emailUsed, isNull);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'person@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        ' password with spaces ',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).at(1));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(TextFormField).at(1)).bottom,
        lessThanOrEqualTo(480),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(auth.emailUsed, 'person@example.com');
      expect(auth.passwordUsed, ' password with spaces ');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(auth.googleCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('registration, password reset and readable login errors', (
    tester,
  ) async {
    final auth = LoginAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(theme: MetCueTheme.light, home: const AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.com',
    );
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(auth.resetEmail, 'person@example.com');
    expect(find.textContaining('If this email has an account'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    auth.fail = true;
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(
      find.text('Check your email and password, then try again.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('New here? Create account'));
    await tester.tap(find.text('New here? Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'short');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(auth.registerCalls, 0);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'strong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(auth.registerCalls, 1);
  });
  testWidgets(
    'login gate, offline choice and account onboarding stay isolated',
    (tester) async {
      final storage = await StorageService.init();
      await storage.setOnboardingCompleted(true);
      await storage.addDemoConnectionsOnce();
      final auth = LoginAuth();
      final cards = CardsProvider(storage);
      final people = ConnectionsProvider(storage);
      final profile = AccountProfileProvider(storage);
      addTearDown(profile.dispose);
      addTearDown(auth.dispose);
      addTearDown(cards.dispose);
      addTearDown(people.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider.value(value: cards),
            ChangeNotifierProvider.value(value: people),
            ChangeNotifierProvider.value(value: profile),
          ],
          child: MaterialApp(
            theme: MetCueTheme.light,
            home: AccountWalletGate(storage: storage),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Continue on this device'), findsNothing);
      auth.login('alice');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(storage.scope, 'alice');
      expect(storage.hasCompletedOnboarding, isTrue);
      expect(await storage.loadConnections(), hasLength(20));
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(await storage.loadConnections(), isEmpty);
      auth.login('bob');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(storage.scope, 'bob');
      expect(storage.hasCompletedOnboarding, isFalse);
      expect(await storage.loadConnections(), isEmpty);
      expect(find.byType(AccountProfileScreen), findsOneWidget);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
