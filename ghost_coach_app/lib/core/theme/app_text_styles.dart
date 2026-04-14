import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Ghost Coach Typography System
///
/// Font strategy:
/// - BRAND:  Orbitron      → "GHOST COACH" logo text only
/// - HEADS:  Space Grotesk → Section headers, scores, grades
/// - BODY:   Inter         → Descriptions, tips, labels
/// - MONO:   JetBrains Mono→ Numbers, stats, timestamps
class AppTextStyles {
  AppTextStyles._();

  // ─── BRAND / LOGO ───
  /// Orbitron bold — ONLY for "GHOST COACH" brand text.
  static TextStyle get brand => GoogleFonts.orbitron(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 4,
    color: AppColors.textPrimary,
  );

  /// Orbitron small — compact brand mark (app bar, nav labels)
  static TextStyle get brandSmall => GoogleFonts.orbitron(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.textPrimary,
  );

  // ─── HEADINGS (Space Grotesk) ───
  static TextStyle get heading1 => GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading2 => GoogleFonts.spaceGrotesk(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading3 => GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  /// Capitalized label / section header with wide tracking
  static TextStyle get sectionLabel => GoogleFonts.spaceGrotesk(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
    color: AppColors.textSecondary,
  );

  // ─── BODY (Inter) ───
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
  );

  // ─── STATS / MONO (JetBrains Mono) ───
  /// Large score / number display
  static TextStyle get stat => GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Medium stat
  static TextStyle get statMedium => GoogleFonts.jetBrainsMono(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Small stat (bar labels, percentages)
  static TextStyle get statSmall => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Tiny mono (timestamps, IDs)
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
  );
}