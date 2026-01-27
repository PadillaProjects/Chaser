import 'package:flutter/material.dart';

/// Horror/Thriller color palette for the Chaser app
class AppColors {
  AppColors._();

  // Core Palette
  static const Color voidBlack = Color(0xFF0A0A0A);
  static const Color fogGrey = Color(0xFF1A1A1A);
  static const Color bloodRed = Color(0xFFFF3B30);
  static const Color pulseBlue = Color(0xFF32AADF);
  static const Color ghostWhite = Color(0xFFE0E0E0);
  static const Color toxicGreen = Color(0xFF2ECC71);
  static const Color warningYellow = Color(0xFFF1C40F);

  // Semantic Colors
  static const Color chaserColor = bloodRed;
  static const Color runnerColor = pulseBlue;
  static const Color dangerColor = bloodRed;
  static const Color safetyColor = pulseBlue;
  static const Color staminaColor = toxicGreen;
  static const Color closeCallColor = warningYellow;

  // Surface Colors
  static const Color surfacePrimary = voidBlack;
  static const Color surfaceSecondary = fogGrey;
  static const Color cardBackground = fogGrey;

  // Text Colors
  static const Color textPrimary = ghostWhite;
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF666666);
}
