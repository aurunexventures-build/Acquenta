import 'package:flutter/material.dart';

/// Shared application surfaces; individual visiting cards keep their own colours.
abstract final class MetCueTheme {
  static const paper = Color(0xFFF6F5F1);
  static const ink = Color(0xFF202128);
  static const purple = Color(0xFF2563EB);
  static const muted = Color(0xFF82798E);
  static const border = Color(0xFFDEE5F0);

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.light,
        ).copyWith(
          primary: purple,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: border,
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: border),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      hintColor: muted,
      dividerColor: border,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: rounded,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: purple),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: purple, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        modalBackgroundColor: paper,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE6EEFF),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
