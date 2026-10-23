import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../providers/customer_providers.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    required this.productId,
    this.filledBackground = true,
    super.key,
  });

  final String productId;
  final bool filledBackground;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref
        .watch(favoriteIdsProvider)
        .contains(widget.productId);
    final brand = context.brand;
    return IconButton(
      tooltip: isFavorite ? 'Remove from favorites' : 'Save to favorites',
      onPressed: _busy ? null : () => _toggle(isFavorite),
      style: IconButton.styleFrom(
        backgroundColor: widget.filledBackground
            ? Colors.white.withValues(alpha: 0.96)
            : null,
        foregroundColor: isFavorite ? brand.primary : brand.inkMuted,
        minimumSize: const Size(38, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 19,
            ),
    );
  }

  Future<void> _toggle(bool isFavorite) async {
    if (ref.read(currentSessionProvider).isGuest) {
      context.push(Routes.signIn);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(growthRepositoryProvider)
          .setFavorite(widget.productId, !isFavorite);
      ref.invalidate(favoritesProvider);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
