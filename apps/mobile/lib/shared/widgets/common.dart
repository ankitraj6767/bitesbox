import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/theme/brand_tokens.dart';

/// Veg / non-veg marker. Regulated signalling in India, so the colours are fixed
/// rather than themed, and it always carries a semantic label for screen readers.
class FoodTypeMark extends StatelessWidget {
  const FoodTypeMark({required this.foodType, this.size = 14, super.key});

  final String foodType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    final (colour, label) = switch (foodType) {
      'NON_VEG' => (brand.nonVeg, 'Non-vegetarian'),
      'EGG' => (brand.egg, 'Contains egg'),
      'VEGAN' => (brand.veg, 'Vegan'),
      _ => (brand.veg, 'Vegetarian'),
    };

    return Semantics(
      label: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: colour, width: 1.6),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Food photography with caching, a graceful placeholder and a fallback.
///
/// Images come from Supabase Storage public buckets. Paths in the database
/// already include the bucket prefix, so this resolves them to a CDN URL.
class FoodImage extends StatelessWidget {
  const FoodImage({
    required this.path,
    this.width,
    this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? path;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  static const _knownBuckets = {
    'menu-images',
    'banners',
    'brand-assets',
    'staff-photos',
  };

  /// Storage object path → public CDN URL.
  static String? resolve(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;

    final segments = path.split('/');
    final bucket = segments.first;
    final hasBucket = _knownBuckets.contains(bucket);

    final resolvedBucket = hasBucket ? bucket : 'menu-images';
    final objectPath = hasBucket ? segments.skip(1).join('/') : path;

    return '${Env.supabaseUrl}/storage/v1/object/public/$resolvedBucket/$objectPath';
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final url = resolve(path);

    final placeholder = Container(
      width: width,
      height: height,
      color: brand.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: brand.inkMuted.withValues(alpha: 0.35),
          size: (height ?? 48) * 0.32,
        ),
      ),
    );

    if (url == null) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: placeholder);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => placeholder,
        // A missing image must never break a menu card.
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}

/// Small pill used for tags, statuses and badges.
class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.dense = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final fg = foreground ?? brand.inkMuted;
    final bg = background ?? brand.surfaceMuted;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 3 : 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header used across the home screen and menu.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 22, 16, 12),
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                    color: brand.ink,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 13.5, color: brand.inkMuted, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Quantity stepper used in the cart and on the product sheet.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 50,
    this.busy = false,
    this.dense = false,
    super.key,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool busy;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final size = dense ? 30.0 : 36.0;

    return Container(
      decoration: BoxDecoration(
        color: brand.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(brand.radiusSm),
        border: Border.all(color: brand.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: quantity <= min ? Icons.delete_outline_rounded : Icons.remove_rounded,
            size: size,
            colour: brand.primary,
            onTap: busy ? null : () => onChanged(quantity - 1),
            semanticLabel: quantity <= min ? 'Remove item' : 'Decrease quantity',
          ),
          SizedBox(
            width: dense ? 26 : 32,
            child: busy
                ? Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.8, color: brand.primary),
                    ),
                  )
                : Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: dense ? 13.5 : 15,
                      fontWeight: FontWeight.w700,
                      color: brand.primary,
                    ),
                  ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            size: size,
            colour: brand.primary,
            onTap: busy || quantity >= max ? null : () => onChanged(quantity + 1),
            semanticLabel: 'Increase quantity',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.size,
    required this.colour,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final Color colour;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.46,
            color: onTap == null ? colour.withValues(alpha: 0.35) : colour,
          ),
        ),
      ),
    );
  }
}

/// Rating chip: ★ 4.7 (96)
class RatingChip extends StatelessWidget {
  const RatingChip({required this.rating, this.count, this.dense = false, super.key});

  final num rating;
  final int? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (rating <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: dense ? 13 : 15, color: brand.success),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: dense ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: brand.ink,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: TextStyle(fontSize: dense ? 11 : 12, color: brand.inkMuted),
          ),
        ],
      ],
    );
  }
}
