import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand_tokens.dart';

/// Builds the Material theme from [BrandTokens].
///
/// Two variants because the surfaces have different jobs:
///   · [customer] — warm, food-first, generous spacing, premium feel
///   · [operations] — dense, high contrast, very large touch targets for a
///     kitchen tablet or a rider using one hand on a scooter
abstract final class AppTheme {
  static ThemeData customer(BrandTokens brand) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand.primary,
      primary: brand.primary,
      secondary: brand.secondary,
      surface: brand.surface,
      error: brand.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brand.canvas,
      fontFamily: null, // Platform default: Roboto on Android, SF on iOS.
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, brand),
      appBarTheme: AppBarTheme(
        backgroundColor: brand.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: brand.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: brand.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: brand.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          side: BorderSide(color: brand.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.radiusMd)),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand.ink,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: brand.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand.primary,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(color: brand.inkMuted.withValues(alpha: 0.8), fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.error, width: 1.6),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: brand.surface,
        selectedItemColor: brand.primary,
        unselectedItemColor: brand.inkMuted,
        selectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brand.surfaceMuted,
        side: BorderSide(color: brand.hairline),
        labelStyle: TextStyle(fontSize: 13, color: brand.ink, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: brand.hairline, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brand.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(brand.radiusXl)),
        ),
        showDragHandle: true,
        dragHandleColor: brand.hairline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: brand.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brand.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.radiusSm)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: brand.primary),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// Kitchen and delivery: bigger type, bigger targets, flatter surfaces. These
  /// screens are read at arm's length in a hot, bright room.
  static ThemeData operations(BrandTokens brand) {
    final base = customer(brand);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F5F7),
      textTheme: base.textTheme.apply(fontSizeFactor: 1.08),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: Colors.white,
          // Gloved hands, moving vehicles: never smaller than this.
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.radiusMd)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand.ink,
          minimumSize: const Size.fromHeight(58),
          side: BorderSide(color: brand.hairline, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.radiusMd)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          side: BorderSide(color: brand.hairline, width: 1.2),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, BrandTokens brand) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.1,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.15,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
          bodySmall: base.bodySmall?.copyWith(color: brand.inkMuted, height: 1.4),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: brand.ink, displayColor: brand.ink);
  }
}
