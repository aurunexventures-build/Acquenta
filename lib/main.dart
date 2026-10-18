import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'theme/metcue_theme.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/cards_provider.dart';
import 'providers/account_profile_provider.dart';
import 'screens/account_profile_screen.dart';
import 'dart:async';
import 'providers/connections_provider.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_card_builder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: kIsWeb
          ? metCueWebOptions
          : defaultTargetPlatform == TargetPlatform.iOS
          ? metCueIosOptions
          : null,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialise the local wallet; demo fixtures are only used by tests.
  final storageService = await StorageService.init();

  runApp(ContactCardBuilderApp(storageService: storageService));
}

class ContactCardBuilderApp extends StatelessWidget {
  final StorageService storageService;
  final bool requireSignIn;

  const ContactCardBuilderApp({
    super.key,
    required this.storageService,
    this.requireSignIn = true,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CardsProvider(storageService)),
        ChangeNotifierProvider(
          create: (_) => AccountProfileProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectionsProvider(storageService),
        ),
      ],
      child: MaterialApp(
        title: 'Acquenta',
        debugShowCheckedModeBanner: false,
        theme: MetCueTheme.light,
        themeMode: ThemeMode.light,
        home: AccountWalletGate(
          storage: storageService,
          requireSignIn: requireSignIn,
        ),
      ),
    );
  }
}

class AccountWalletGate extends StatefulWidget {
  final StorageService storage;
  final bool requireSignIn;
  const AccountWalletGate({
    super.key,
    required this.storage,
    this.requireSignIn = true,
  });
  @override
  State<AccountWalletGate> createState() => _AccountWalletGateState();
}

class _AccountWalletGateState extends State<AccountWalletGate>
    with WidgetsBindingObserver {
  late final AuthService _auth;
  String? _uid;
  bool _switching = false;
  bool _offlineMode = false;
  Future<void> _switchQueue = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthService>();
    _auth.addListener(_onAuth);
    context.read<ConnectionsProvider>().bindAuth(
      _auth,
      cards: context.read<CardsProvider>(),
    );
    _onAuth();
  }

  void _onAuth() {
    final uid = _auth.currentUser?.uid;
    if (uid == _uid) return;
    _offlineMode = false;
    _uid = uid;
    if (mounted) setState(() => _switching = true);
    final cards = context.read<CardsProvider>();
    final connections = context.read<ConnectionsProvider>();
    final profile = context.read<AccountProfileProvider>();
    profile.clearForAccountSwitch();
    cards.clearForAccountSwitch();
    connections.clearForAccountSwitch();
    _switchQueue = _switchQueue.then((_) async {
      await widget.storage.activateAccount(uid);
      if (!mounted || _uid != uid) return;
      await cards.loadCards();
      await connections.loadConnections();
      await profile.load(_auth);
      if (!mounted || _uid != uid) return;
      connections.bindAuth(_auth, cards: cards);
      setState(() => _switching = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_switching) {
      unawaited(context.read<AccountProfileProvider>().sync());
      context.read<ConnectionsProvider>().syncSoon();
      context.read<ConnectionsProvider>().refreshReminders();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuth);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();
    context.watch<CardsProvider>();
    final profile = context.watch<AccountProfileProvider>();
    if (_switching) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.requireSignIn && !_auth.isAuthenticated && !_offlineMode) {
      return AuthScreen(
        onContinueOffline: () => setState(() => _offlineMode = true),
      );
    }
    if (!widget.storage.hasCompletedOnboarding && profile.profile == null) {
      return const AccountProfileScreen(setup: true);
    }
    return widget.storage.hasCompletedOnboarding
        ? const HomeScreen()
        : OnboardingCardBuilderScreen(storageService: widget.storage);
  }
}
