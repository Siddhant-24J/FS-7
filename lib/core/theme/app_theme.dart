import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandOrange,
        onPrimary: Colors.white,
        secondary: AppColors.brandOrange,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        background: AppColors.background,
        onBackground: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brandOrange,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandOrange.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.brandOrange);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.brandOrange,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brandOrange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandOrange,
          side: const BorderSide(color: AppColors.brandOrange),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandOrange,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceRaised,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      textTheme: textTheme,
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    const defaultFont = 'Inter';
    return base.copyWith(
      displayLarge: const TextStyle(
        fontFamily: defaultFont, fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
      ),
      displayMedium: const TextStyle(
        fontFamily: defaultFont, fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      displaySmall: const TextStyle(
        fontFamily: defaultFont, fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      headlineLarge: const TextStyle(
        fontFamily: defaultFont, fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      headlineMedium: const TextStyle(
        fontFamily: defaultFont, fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      headlineSmall: const TextStyle(
        fontFamily: defaultFont, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontFamily: defaultFont, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontFamily: defaultFont, fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleSmall: const TextStyle(
        fontFamily: defaultFont, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
      ),
      bodyLarge: const TextStyle(
        fontFamily: defaultFont, fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontFamily: defaultFont, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontFamily: defaultFont, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
      ),
      labelLarge: const TextStyle(
        fontFamily: defaultFont, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
      ),
      labelMedium: const TextStyle(
        fontFamily: defaultFont, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
      ),
      labelSmall: const TextStyle(
        fontFamily: defaultFont, fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
      ),
    );
  }
}

