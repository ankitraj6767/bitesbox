import 'package:flutter/material.dart';

import '../core/errors/app_error.dart';
import '../core/theme/brand_tokens.dart';

/// Snackbars, confirmations and bottom sheets, in one place so every screen
/// reports success and failure the same way.
abstract final class AppFeedback {
  /// Shows a customer-safe message for any thrown object.
  static void showError(BuildContext context, Object error) {
    final appError = error is AppError ? error : AppError.from(error);
    final brand = context.brand;

    _show(
      context,
      message: appError.message,
      background: brand.error,
      icon: appError.code == ErrorCodes.networkError
          ? Icons.wifi_off_rounded
          : Icons.error_outline_rounded,
      duration: const Duration(seconds: 4),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      background: context.brand.success,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      background: context.brand.ink,
      icon: Icons.info_outline_rounded,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color background,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: background,
          duration: duration,
        ),
      );
  }

  /// A yes/no confirmation. Returns false when dismissed.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final brand = context.brand;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: brand.error,
                    minimumSize: const Size(0, 44),
                  )
                : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// A scrollable, keyboard-aware modal sheet.
  static Future<T?> sheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool expand = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: expand
            ? FractionallySizedBox(heightFactor: 0.92, child: builder(sheetContext))
            : builder(sheetContext),
      ),
    );
  }
}

/// A section title used inside bottom sheets.
class SheetHeader extends StatelessWidget {
  const SheetHeader({required this.title, this.subtitle, this.trailing, super.key});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: brand.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 13.5, color: brand.inkMuted, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
