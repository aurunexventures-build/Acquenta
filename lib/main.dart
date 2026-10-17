import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/cards_provider.dart';
import 'providers/connections_provider.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_card_builder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize local persistent storage and realistic seed data
  final storageService = await StorageService.init();

  runApp(ContactCardBuilderApp(storageService: storageService));
}

class ContactCardBuilderApp extends StatelessWidget {
  final StorageService storageService;

  const ContactCardBuilderApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CardsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => ConnectionsProvider(storageService)),
      ],
      child: MaterialApp(
        title: 'MetCue',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 0,
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: Color(0xFFF8FAFC),
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            surface: Color(0xFF14171D),
          ),
          scaffoldBackgroundColor: const Color(0xFF0D0F12),
          cardTheme: const CardThemeData(
            color: Color(0xFF14171D),
            elevation: 0,
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Color(0xFF0D0F12),
            centerTitle: false,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF11141A),
            elevation: 0,
            indicatorColor: Colors.blueAccent.withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold);
              }
              return const TextStyle(color: Colors.white38, fontSize: 11);
            }),
          ),
        ),
        themeMode: ThemeMode.dark,
        home: storageService.hasCompletedOnboarding
            ? const HomeScreen()
            : OnboardingCardBuilderScreen(storageService: storageService),
      ),
    );
  }
}
