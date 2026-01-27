import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chaser/config/colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.voidBlack,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.bloodRed,
        onPrimary: AppColors.ghostWhite,
        secondary: AppColors.pulseBlue,
        onSecondary: AppColors.ghostWhite,
        tertiary: AppColors.toxicGreen,
        error: AppColors.bloodRed,
        surface: AppColors.fogGrey,
        onSurface: AppColors.ghostWhite,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.voidBlack,
        foregroundColor: AppColors.ghostWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.creepster(
          fontSize: 24,
          color: AppColors.ghostWhite,
          letterSpacing: 2,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.fogGrey,
        elevation: 4,
        shadowColor: AppColors.bloodRed.withOpacity(0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: GoogleFonts.creepster(
          fontSize: 48,
          color: AppColors.ghostWhite,
          letterSpacing: 4,
        ),
        displayMedium: GoogleFonts.creepster(
          fontSize: 36,
          color: AppColors.ghostWhite,
          letterSpacing: 3,
        ),
        displaySmall: GoogleFonts.creepster(
          fontSize: 28,
          color: AppColors.ghostWhite,
          letterSpacing: 2,
        ),
        headlineLarge: GoogleFonts.creepster(
          fontSize: 32,
          color: AppColors.ghostWhite,
          letterSpacing: 2,
        ),
        headlineMedium: GoogleFonts.creepster(
          fontSize: 24,
          color: AppColors.ghostWhite,
          letterSpacing: 1.5,
        ),
        headlineSmall: GoogleFonts.jetBrainsMono(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.ghostWhite,
        ),
        titleLarge: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.ghostWhite,
        ),
        titleMedium: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ghostWhite,
        ),
        titleSmall: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ghostWhite,
        ),
        bodyLarge: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          color: AppColors.ghostWhite,
        ),
        bodyMedium: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          color: AppColors.ghostWhite,
        ),
        bodySmall: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.ghostWhite,
          letterSpacing: 1.5,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ghostWhite,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: AppColors.textSecondary,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fogGrey,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.textMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.5)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.bloodRed),
        ),
        labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.jetBrainsMono(color: AppColors.textMuted),
        prefixIconColor: AppColors.textSecondary,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bloodRed,
          foregroundColor: AppColors.ghostWhite,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          elevation: 4,
          shadowColor: AppColors.bloodRed.withOpacity(0.5),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bloodRed,
          foregroundColor: AppColors.ghostWhite,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ghostWhite,
          side: const BorderSide(color: AppColors.ghostWhite),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.bloodRed,
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // FAB Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.bloodRed,
        foregroundColor: AppColors.ghostWhite,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fogGrey,
        labelStyle: GoogleFonts.jetBrainsMono(
          color: AppColors.ghostWhite,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        side: BorderSide.none,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.fogGrey,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        titleTextStyle: GoogleFonts.creepster(
          fontSize: 24,
          color: AppColors.ghostWhite,
        ),
        contentTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          color: AppColors.ghostWhite,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.fogGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.bloodRed,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.bloodRed,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          letterSpacing: 1,
        ),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: AppColors.ghostWhite,
        iconColor: AppColors.textSecondary,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          color: AppColors.ghostWhite,
        ),
        subtitleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.textMuted,
        thickness: 1,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.pulseBlue,
        linearTrackColor: AppColors.fogGrey,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.fogGrey,
        contentTextStyle: GoogleFonts.jetBrainsMono(
          color: AppColors.ghostWhite,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.bloodRed;
          }
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.bloodRed.withOpacity(0.5);
          }
          return AppColors.textMuted;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.bloodRed,
        inactiveTrackColor: AppColors.textMuted,
        thumbColor: AppColors.bloodRed,
        overlayColor: AppColors.bloodRed.withOpacity(0.2),
        valueIndicatorColor: AppColors.bloodRed,
        valueIndicatorTextStyle: GoogleFonts.jetBrainsMono(
          color: AppColors.ghostWhite,
        ),
      ),

      // Dropdown Theme
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.fogGrey,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.ghostWhite,
      ),

      // Primary Icon Theme
      primaryIconTheme: const IconThemeData(
        color: AppColors.ghostWhite,
      ),
    );
  }
}
