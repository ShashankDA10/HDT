import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color ink = Color(0xFF070B14);
  static const Color surface = Color(0xFF0C1323);
  static const Color surfaceElevated = Color(0xFF131D33);
  static const Color surfaceSoft = Color(0xFF0E172B);
  static const Color accent = Color(0xFF35F2D5);
  static const Color accentBlue = Color(0xFF5CA9FF);
  static const Color accentViolet = Color(0xFF9D7BFF);
  static const Color accentAmber = Color(0xFFF6A03A);
  static const Color accentRose = Color(0xFFFF6FAE);
  static const Color outline = Color(0xFF22304B);
  static const Color muted = Color(0xFF8A94A8);
  static const Color warning = Color(0xFFF4B740);
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFFF5C8D);
}

class AppDecorations {
  static const Gradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF121B2F),
      Color(0xFF0D1527),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF1A2744),
      Color(0xFF0F1A32),
      Color(0xFF0A1226),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient softGlow = RadialGradient(
    colors: [
      Color(0x332DD4BF),
      Color(0x00000000),
    ],
    radius: 0.8,
  );
}

class AppTheme {
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentBlue,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: AppColors.ink,
      onSecondary: AppColors.ink,
      onSurface: Colors.white,
      onError: Colors.white,
    );

    final display = GoogleFonts.outfitTextTheme(const TextTheme());
    final baseTextTheme = GoogleFonts.manropeTextTheme(const TextTheme())
        .apply(bodyColor: Colors.white, displayColor: Colors.white);

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink,
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: _SoftPageTransitionsBuilder(),
        },
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        displayMedium: display.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        displaySmall: display.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: display.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: display.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleSmall: display.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.5),
        bodySmall: baseTextTheme.bodySmall?.copyWith(height: 1.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
        size: 22,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
      dividerColor: AppColors.outline,
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.ink,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: AppColors.outline.withOpacity(0.8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: AppColors.outline.withOpacity(0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.ink,
      ),
    );
  }
}

class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == '/') {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
