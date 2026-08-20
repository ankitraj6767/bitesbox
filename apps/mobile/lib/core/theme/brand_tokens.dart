import 'package:flutter/material.dart';

/// Brand tokens.
///
/// Defaults are compiled in so the very first frame is on-brand, then
/// [BrandTokens.fromSettings] overlays whatever the operator has configured in
/// `settings` (brand.color_*). Rebranding is therefore a database change, not an
/// app release.
@immutable
class BrandTokens {
  const BrandTokens({
    this.name = 'Bites Box',
    this.tagline = 'Bihar ka swaad, box mein.',
    this.primary = const Color(0xFFC1121F),
    this.primaryDark = const Color(0xFF8E0D17),
    this.secondary = const Color(0xFF1B4332),
    this.accent = const Color(0xFFF0A202),
    this.canvas = const Color(0xFFFFFBF6),
    this.surface = Colors.white,
    this.surfaceMuted = const Color(0xFFF9F5F0),
    this.hairline = const Color(0xFFECE5DD),
    this.ink = const Color(0xFF1A1614),
    this.inkMuted = const Color(0xFF6B625C),
    this.success = const Color(0xFF1B7F4B),
    this.warning = const Color(0xFFB45309),
    this.error = const Color(0xFFB3261E),
    this.radiusScale = 1.0,
    this.logoPath,
  });

  final String name;
  final String tagline;

  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color accent;

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color hairline;

  final Color ink;
  final Color inkMuted;

  final Color success;
  final Color warning;
  final Color error;

  final double radiusScale;
  final String? logoPath;

  // Consistent radii and spacing across the whole app.
  double get radiusSm => 8 * radiusScale;
  double get radiusMd => 14 * radiusScale;
  double get radiusLg => 20 * radiusScale;
  double get radiusXl => 28 * radiusScale;

  /// Veg / non-veg markers are regulated signalling in India — keep them fixed
  /// rather than theming them.
  Color get veg => const Color(0xFF1B7F4B);
  Color get nonVeg => const Color(0xFFB3261E);
  Color get egg => const Color(0xFFB45309);

  /// Builds tokens from the `settings` map returned by `public.app_config()`.
  factory BrandTokens.fromSettings(Map<String, dynamic> settings) {
    Color colour(String key, Color fallback) {
      final raw = settings[key];
      if (raw is! String) return fallback;
      return _parseHex(raw) ?? fallback;
    }

    String text(String key, String fallback) {
      final raw = settings[key];
      return raw is String && raw.trim().isNotEmpty ? raw : fallback;
    }

    const defaults = BrandTokens();

    return BrandTokens(
      name: text('brand.name', defaults.name),
      tagline: text('brand.tagline', defaults.tagline),
      primary: colour('brand.color_primary', defaults.primary),
      primaryDark: colour('brand.color_primary_dark', defaults.primaryDark),
      secondary: colour('brand.color_secondary', defaults.secondary),
      accent: colour('brand.color_accent', defaults.accent),
      canvas: colour('brand.color_background', defaults.canvas),
      surface: colour('brand.color_surface', defaults.surface),
      ink: colour('brand.color_text_primary', defaults.ink),
      inkMuted: colour('brand.color_text_secondary', defaults.inkMuted),
      success: colour('brand.color_success', defaults.success),
      warning: colour('brand.color_warning', defaults.warning),
      error: colour('brand.color_error', defaults.error),
      radiusScale: (settings['brand.radius_scale'] as num?)?.toDouble() ?? 1.0,
      logoPath: settings['brand.logo_path'] as String?,
    );
  }

  static Color? _parseHex(String value) {
    final hex = value.replaceAll('#', '').trim();
    if (hex.length != 6 && hex.length != 8) return null;

    final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

/// Makes tokens available to the widget tree without threading them through
/// every constructor.
class BrandTheme extends InheritedWidget {
  const BrandTheme({required this.tokens, required super.child, super.key});

  final BrandTokens tokens;

  static BrandTokens of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<BrandTheme>();
    return theme?.tokens ?? const BrandTokens();
  }

  @override
  bool updateShouldNotify(BrandTheme oldWidget) => oldWidget.tokens != tokens;
}

extension BrandContext on BuildContext {
  BrandTokens get brand => BrandTheme.of(this);
}
