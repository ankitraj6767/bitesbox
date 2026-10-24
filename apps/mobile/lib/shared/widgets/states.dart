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
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: brand.primary),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: TextStyle(color: brand.inkMuted, fontSize: 13.5)),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder block. Used to hold layout while content loads, which
/// stops the menu from jumping around on a slow connection.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.radius = 8,
    super.key,
  });

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

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: brand.surfaceMuted, shape: BoxShape.circle),
              child: Icon(icon, color: brand.inkMuted, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: brand.ink),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.45, color: brand.inkMuted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
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
    final appError = error is AppError ? error as AppError : AppError.from(error);
    final offline = appError.code == ErrorCodes.networkError;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: brand.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                color: brand.error,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              offline ? 'You are offline' : 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: brand.ink),
            ),
            const SizedBox(height: 6),
            Text(
              appError.message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: brand.inkMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
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
