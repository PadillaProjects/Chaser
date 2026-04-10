import 'package:flutter/material.dart';

/// Horror/Thriller color palette for the Chaser app
class AppColors {
  AppColors._();

  // Core Palette
  static const Color voidBlack = Color(0xFF000000); // Pure absolute black
  static const Color fogGrey = Color(0xFF0D0D0D); // Almost pitch black
  static const Color bloodRed = Color(0xFFFFFFFF); // Blinding Pure White (Danger/Threat)
  static const Color pulseBlue = Color(0xFF8C8C8C); // Ash Grey (Runner/Weakness)
  static const Color ghostWhite = Color(0xFFE6E6E6); // Off-White
  static const Color toxicGreen = Color(0xFF595959); // Dark Ash (Stamina/Muted)
  static const Color warningYellow = Color(0xFFB3B3B3); // Light Ash (Warning)

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
  static const Color textSecondary = Color(0xFF737373);
  static const Color textMuted = Color(0xFF4A4A4A);
}
