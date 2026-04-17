import 'dart:ui';
import 'package:flutter/material.dart';

/// Ghost Coach Glassmorphism Design System Colors
class AppColors {
  AppColors._();

  static bool get isDark {
    try {
      final brightness = PlatformDispatcher.instance.platformBrightness;
      return brightness == Brightness.dark;
    } catch (_) {
      return true;
    }
  }

  // ─── BACKGROUNDS ───
  static Color get background => isDark ? const Color(0xFF1B2A3B) : const Color(0xFFFDFDFD);
  static Color get surface => isDark ? const Color(0xFF243A52) : const Color(0xFFFFFFFF);
  static Color get surfaceLight => isDark ? const Color(0xFF355C7D) : const Color(0xFFF3F4F6); // Using the Navy/Steel Blue #355C7D

  // ─── PRIMARY PALETTE ───
  static Color get primary => const Color(0xFFF67280); // Light Coral
  static Color get primaryLight => const Color(0xFFFF9EA6);
  static Color get secondary => const Color(0xFFC06C84); // Mauve
  static Color get accent => const Color(0xFF6C5B7B); // Purple

  // ─── SEMANTIC ───
  static Color get success => const Color(0xFF22C55E); // Neon Green
  static Color get warning => const Color(0xFFF59E0B); // Amber
  static Color get error => const Color(0xFFEF4444); // Red

  // ─── GLASS SURFACES (translucent — for overlays) ───
  static Color get glassFill => isDark ? const Color(0x20FFFFFF) : const Color(0x1AF67280);
  static Color get glassBorder => isDark ? const Color(0x33FFFFFF) : const Color(0x33F67280);
  static Color get border => isDark ? const Color(0x2EFFFFFF) : const Color(0x20355C7D);
  static Color get borderSubtle => isDark ? const Color(0x14FFFFFF) : const Color(0x0A355C7D);

  // ─── TEXT ───
  static Color get textPrimary => isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1B2A3B);
  static Color get textSecondary => isDark ? const Color(0xB3FFFFFF) : const Color(0x991B2A3B);
  static Color get textTertiary => isDark ? const Color(0x66FFFFFF) : const Color(0x661B2A3B);

  // ─── GRADE COLORS ───
  static Color get gradeS => const Color(0xFFFFD700); // Gold
  static Color get gradeA => const Color(0xFF22C55E); // Green
  static Color get gradeB => const Color(0xFF3B82F6); // Blue
  static Color get gradeC => const Color(0xFFF59E0B); // Amber/Yellow
  static Color get gradeD => const Color(0xFFF97316); // Orange
  static Color get gradeF => const Color(0xFFEF4444); // Red

  // ─── GRADIENT PRESETS ───
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => LinearGradient(
    colors: [secondary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── HELPERS ───
  static Color gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'S':
        return gradeS;
      case 'A':
        return gradeA;
      case 'B':
        return gradeB;
      case 'C':
        return gradeC;
      case 'D':
        return gradeD;
      case 'F':
        return gradeF;
      default:
        return gradeC;
    }
  }

  static Color gameColor(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'fortnite':
        return const Color(0xFF00D4FF);
      case 'valorant':
        return const Color(0xFFFF4655);
      case 'warzone':
        return const Color(0xFF8BC34A);
      case 'soccer':
        return const Color(0xFFFFFFFF);
      default:
        return const Color(0xFFAB47BC);
    }
  }

  static String gameLabel(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'fortnite':
        return 'FORTNITE';
      case 'valorant':
        return 'VALORANT';
      case 'warzone':
        return 'WARZONE';
      case 'soccer':
        return 'SOCCER';
      default:
        return 'GENERAL';
    }
  }

  static Color scoreColor(double score) {
    if (score >= 90) return gradeS;
    if (score >= 75) return gradeA;
    if (score >= 60) return gradeB;
    if (score >= 45) return gradeC;
    if (score >= 30) return gradeD;
    return gradeF;
  }
}