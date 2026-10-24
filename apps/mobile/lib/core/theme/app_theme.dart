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
      scaffoldBackgroundColor: brand.customerCanvas,
      fontFamily: null, // Platform default: Roboto on Android, SF on iOS.
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, brand),
      appBarTheme: AppBarTheme(
        backgroundColor: brand.customerCanvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: brand.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: brand.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
      ),
      cardTheme: CardThemeData(
        color: brand.surface,
        elevation: 1,
        shadowColor: brand.ink.withValues(alpha: 0.045),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusLg),
          side: BorderSide(color: brand.hairline.withValues(alpha: 0.8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(brand.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: brand.hairline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(brand.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand.primary,
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 17,
        ),
        hintStyle: TextStyle(
          color: brand.inkMuted.withValues(alpha: 0.8),
          fontSize: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.hairline, width: 1.1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.hairline, width: 1.1),
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
        selectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brand.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.1,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: brand.ink,
        unselectedLabelColor: brand.inkMuted,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: brand.primary, width: 3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        dividerColor: brand.hairline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: brand.inkMuted,
        textColor: brand.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand.ink,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brand.surfaceMuted,
        side: BorderSide(color: brand.hairline),
        labelStyle: TextStyle(
          fontSize: 13,
          color: brand.ink,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: brand.hairline,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brand.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(brand.radiusXl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: brand.hairline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: brand.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusXl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brand.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusSm),
        ),
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
      scaffoldBackgroundColor: brand.canvas,
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: brand.canvas),
      textTheme: base.textTheme.apply(fontSizeFactor: 1.08),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: Colors.white,
          // Gloved hands, moving vehicles: never smaller than this.
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(brand.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand.ink,
          minimumSize: const Size.fromHeight(58),
          side: BorderSide(color: brand.hairline, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(brand.radiusMd),
          ),
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
            letterSpacing: -1.1,
            height: 1.1,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.08,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            height: 1.12,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
          bodySmall: base.bodySmall?.copyWith(
            color: brand.inkMuted,
            height: 1.4,
          ),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: brand.ink, displayColor: brand.ink);
  }
}
