import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:beti_app/core/constants/app_colors.dart';

/// Tema global de Betty con soporte para modo claro/oscuro.
/// Incluye CupertinoThemeData para widgets adaptativos en iOS.
class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════════════════
  // Material 3 — Light
  // ══════════════════════════════════════════════════════════
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.textPrimaryLight,
          secondary: AppColors.accent,
          error: AppColors.expense,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.textPrimaryLight,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimaryLight,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.lightGrey.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.lightGrey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.surfaceLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimaryLight,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(color: AppColors.lightGrey.withValues(alpha: 0.4)),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: AppColors.surfaceLight,
          margin: EdgeInsets.zero,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          elevation: 0,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 24);
            }
            return const IconThemeData(color: AppColors.grey, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return const TextStyle(
              color: AppColors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            );
          }),
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.lightGrey.withValues(alpha: 0.3),
          thickness: 0.5,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════
  // Material 3 — Dark
  // ══════════════════════════════════════════════════════════
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.textPrimaryDark,
          secondary: AppColors.accent,
          error: AppColors.expense,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.textPrimaryDark,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.grey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.grey.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.surfaceDark,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimaryDark,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(color: AppColors.grey.withValues(alpha: 0.3)),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: AppColors.surfaceDark,
          margin: EdgeInsets.zero,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 24);
            }
            return IconThemeData(color: AppColors.lightGrey.withValues(alpha: 0.7), size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return TextStyle(
              color: AppColors.lightGrey.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            );
          }),
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.grey.withValues(alpha: 0.2),
          thickness: 0.5,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════
  // Cupertino — para widgets iOS adaptativos
  // ══════════════════════════════════════════════════════════
  static CupertinoThemeData get cupertinoLight => const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        barBackgroundColor: AppColors.surfaceLight,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.primary,
          textStyle: TextStyle(
            color: AppColors.textPrimaryLight,
            fontSize: 16,
          ),
          navTitleTextStyle: TextStyle(
            color: AppColors.textPrimaryLight,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          tabLabelTextStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  static CupertinoThemeData get cupertinoDark => const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        barBackgroundColor: AppColors.surfaceDark,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.primary,
          textStyle: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 16,
          ),
          navTitleTextStyle: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          tabLabelTextStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
