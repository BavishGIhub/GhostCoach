import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class GhostTheme {
  static ThemeData get darkTheme {
    // Inter for body (base theme)
    final bodyTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    // Font families
    final orbitronFamily = GoogleFonts.orbitron().fontFamily;
    final spaceGroteskFamily = GoogleFonts.spaceGrotesk().fontFamily;
    final jetbrainsFamily = GoogleFonts.jetBrainsMono().fontFamily;

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.secondary,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accent,
      onSecondaryContainer: Colors.white,
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.surfaceLight,
      onTertiaryContainer: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFF5C1010),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceLight,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSubtle,
      inverseSurface: const Color(0xFFE5E2E1),
      onInverseSurface: const Color(0xFF313030),
      inversePrimary: AppColors.primary,
      surfaceTint: AppColors.primary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      textTheme: bodyTextTheme.copyWith(
        // Brand/Display: Orbitron — used exclusively for "GHOST COACH" brand text
        displayLarge: bodyTextTheme.displayLarge?.copyWith(
          fontFamily: orbitronFamily,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
        displayMedium: bodyTextTheme.displayMedium?.copyWith(
          fontFamily: orbitronFamily,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        displaySmall: bodyTextTheme.displaySmall?.copyWith(
          fontFamily: orbitronFamily,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),

        // Headings: Space Grotesk
        headlineLarge: bodyTextTheme.headlineLarge?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: bodyTextTheme.headlineMedium?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: bodyTextTheme.headlineSmall?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: bodyTextTheme.titleLarge?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: bodyTextTheme.titleMedium?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: bodyTextTheme.titleSmall?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),

        // Labels: Space Grotesk with wide tracking (buttons, chips, caps)
        labelLarge: bodyTextTheme.labelLarge?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        labelMedium: bodyTextTheme.labelMedium?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        labelSmall: bodyTextTheme.labelSmall?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),

        // Body: Inter (from base bodyTextTheme — default)
        // bodyLarge, bodyMedium, bodySmall remain as InterTextTheme applies

        // Override bodyLarge to use JetBrains Mono — scores/stats
        bodyLarge: bodyTextTheme.bodyLarge?.copyWith(
          fontFamily: jetbrainsFamily,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.secondary),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 2.0,
        ),
      ),

      iconTheme: IconThemeData(color: AppColors.textPrimary),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    // Inter for body (base theme)
    final bodyTextTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    );

    // Font families
    final orbitronFamily = GoogleFonts.orbitron().fontFamily;
    final spaceGroteskFamily = GoogleFonts.spaceGrotesk().fontFamily;
    final jetbrainsFamily = GoogleFonts.jetBrainsMono().fontFamily;

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.background,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accent,
      onSecondaryContainer: Colors.white,
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.surfaceLight,
      onTertiaryContainer: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF5C1010),
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceLight,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSubtle,
      inverseSurface: const Color(0xFF313030),
      onInverseSurface: const Color(0xFFE5E2E1),
      inversePrimary: AppColors.primary,
      surfaceTint: AppColors.primary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      textTheme: bodyTextTheme.copyWith(
        // Brand/Display: Orbitron — used exclusively for "GHOST COACH" brand text
        displayLarge: bodyTextTheme.displayLarge?.copyWith(
          fontFamily: orbitronFamily,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
        displayMedium: bodyTextTheme.displayMedium?.copyWith(
          fontFamily: orbitronFamily,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        displaySmall: bodyTextTheme.displaySmall?.copyWith(
          fontFamily: orbitronFamily,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),

        // Headings: Space Grotesk
        headlineLarge: bodyTextTheme.headlineLarge?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: bodyTextTheme.headlineMedium?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: bodyTextTheme.headlineSmall?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: bodyTextTheme.titleLarge?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: bodyTextTheme.titleMedium?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: bodyTextTheme.titleSmall?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
        ),

        // Labels: Space Grotesk with wide tracking (buttons, chips, caps)
        labelLarge: bodyTextTheme.labelLarge?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        labelMedium: bodyTextTheme.labelMedium?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        labelSmall: bodyTextTheme.labelSmall?.copyWith(
          fontFamily: spaceGroteskFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),

        // Body: Inter (from base bodyTextTheme — default)
        // bodyLarge, bodyMedium, bodySmall remain as InterTextTheme applies

        // Override bodyLarge to use JetBrains Mono — scores/stats
        bodyLarge: bodyTextTheme.bodyLarge?.copyWith(
          fontFamily: jetbrainsFamily,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.secondary),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 2.0,
        ),
      ),

      iconTheme: IconThemeData(color: AppColors.textPrimary),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // Gradient getters for auth screens
  static LinearGradient get darkGradient => LinearGradient(
        colors: [
          AppColors.background,
          AppColors.surface,
          AppColors.surfaceLight,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient get lightGradient => LinearGradient(
        colors: [
          Colors.white,
          AppColors.surfaceLight,
          AppColors.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.5, 1.0],
      );
}

// Backward compatibility for gamification widgets
class ExtraColors {
static Color get surfaceContainerLowest => AppColors.background;
static Color get surfaceContainerLow => AppColors.background;
static Color get surfaceContainer => AppColors.surface;
static Color get surfaceContainerHigh => AppColors.surfaceLight;
static Color get surfaceContainerHighest => AppColors.surfaceLight;
}
