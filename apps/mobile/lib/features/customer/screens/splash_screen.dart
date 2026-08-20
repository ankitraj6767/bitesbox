import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';

/// Shown only while the session and platform config resolve.
///
/// The router redirects away as soon as we know who is using the app, so this
/// never becomes a screen anyone waits on for long.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return Scaffold(
      backgroundColor: brand.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(brand.radiusLg),
              ),
              child: Icon(Icons.lunch_dining_rounded, size: 46, color: brand.primary),
            ),
            const SizedBox(height: 22),
            Text(
              brand.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              brand.tagline,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 38),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
