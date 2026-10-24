import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/brand_tokens.dart';

/// Loading, empty and error presentation, in one place so every screen behaves
/// the same way. Restaurant ordering happens on poor connections, so the error
/// state always offers a retry and never blames the customer.

class AppLoader extends StatelessWidget {
  const AppLoader({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: brand.surface,
              shape: BoxShape.circle,
              border: Border.all(color: brand.hairline),
              boxShadow: [
                BoxShadow(
                  color: brand.ink.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: brand.primary,
                backgroundColor: brand.primary.withValues(alpha: 0.10),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: TextStyle(
                color: brand.inkMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder block. Used to hold layout while content loads, which
/// stops the menu from jumping around on a slow connection.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height = 16, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Shimmer.fromColors(
      baseColor: brand.surfaceMuted,
      highlightColor: brand.hairline.withValues(alpha: 0.55),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: brand.surfaceMuted,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final iconSize = compact ? 56.0 : 86.0;
    final glyphSize = compact ? 25.0 : 34.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    brand.primary.withValues(alpha: 0.17),
                    brand.accent.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(compact ? 20 : 28),
                border: Border.all(
                  color: brand.primary.withValues(alpha: 0.11),
                ),
                boxShadow: [
                  BoxShadow(
                    color: brand.primary.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, color: brand.primary, size: glyphSize),
            ),
            SizedBox(height: compact ? 14 : 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 16.5 : 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.45,
                height: 1.2,
                color: brand.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: brand.inkMuted,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? 16 : 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.error,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final appError = error is AppError
        ? error as AppError
        : AppError.from(error);
    final offline = appError.code == ErrorCodes.networkError;
    final iconSize = compact ? 56.0 : 82.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: brand.error.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(compact ? 20 : 27),
                border: Border.all(color: brand.error.withValues(alpha: 0.14)),
              ),
              child: Icon(
                offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                color: brand.error,
                size: compact ? 25 : 32,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              offline ? 'You are offline' : 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 16.5 : 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: brand.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              appError.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: brand.inkMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error handling, while
/// keeping previous data visible during a refresh so the screen never blanks.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Keep showing content while refreshing in the background.
    if (value.hasValue && !value.hasError) {
      return data(value.requireValue);
    }

    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const AppLoader(),
      error: (error, _) {
        // A stale-but-usable value beats an error screen.
        if (value.hasValue) return data(value.requireValue);
        return AppErrorState(error: error, onRetry: onRetry, compact: compact);
      },
    );
  }
}

/// Inline banner for warnings that do not block the screen.
class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.message,
    this.tone = NoticeTone.caution,
    this.icon,
    this.action,
    super.key,
  });

  final String message;
  final NoticeTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    final (background, foreground, defaultIcon) = switch (tone) {
      NoticeTone.caution => (
        brand.warning.withValues(alpha: 0.10),
        brand.warning,
        Icons.info_outline_rounded,
      ),
      NoticeTone.critical => (
        brand.error.withValues(alpha: 0.10),
        brand.error,
        Icons.error_outline_rounded,
      ),
      NoticeTone.positive => (
        brand.success.withValues(alpha: 0.10),
        brand.success,
        Icons.check_circle_outline_rounded,
      ),
      NoticeTone.info => (
        brand.secondary.withValues(alpha: 0.08),
        brand.secondary,
        Icons.info_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: foreground.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

enum NoticeTone { caution, critical, positive, info }
