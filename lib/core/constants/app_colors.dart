import 'package:flutter/material.dart';

/// Minimalistic color palette for StripX v3.
/// Strictly dark mode with muted deep slates and a single electric cyan accent.
class AppColors {
  AppColors._();

  // Dark Base Tones
  static const Color background = Color(0xFF090D13);
  static const Color surface = Color(0xFF0F151F);
  static const Color surfaceElevated = Color(0xFF161E2D);
  static const Color surfaceHighlight = Color(0xFF1E283C);
  
  // Borders
  static const Color border = Color(0xFF1C2536);
  static const Color borderHover = Color(0xFF2A3850);
  static const Color borderAccent = Color(0x6600E5FF);

  // Accents (Electric Cyan / Soft Sky)
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentMuted = Color(0x2200E5FF);
  static const Color accentHover = Color(0xFF38BDF8);
  static const Color secondaryAccent = Color(0xFF38BDF8);
  static const Color accentGlow = Color(0x3300E5FF);

  // Functional Status
  static const Color success = Color(0xFF10B981);
  static const Color successMuted = Color(0x2210B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningMuted = Color(0x22F59E0B);
  static const Color error = Color(0xFFF43F5E);
  static const Color errorMuted = Color(0x22F43F5E);

  // Text Hierarchies
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF475569);

  // Preset minimalist LED colors
  static const List<Color> presetColors = [
    Color(0xFF00E5FF), // Electric Cyan
    Color(0xFF3B82F6), // Pure Blue
    Color(0xFF8B5CF6), // Vapor Violet
    Color(0xFFEC4899), // Neon Pink
    Color(0xFFEF4444), // Crimson
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFF10B981), // Emerald
    Color(0xFFFFFFFF), // Pure White
    Color(0xFFFFF3D4), // Warm White (3000K)
  ];
}
