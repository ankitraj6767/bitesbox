import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/push_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../providers/customer_providers.dart';

/// Collected once, right after a customer's first sign-in.
///
/// A name is required because it appears on the kitchen ticket and the delivery
/// partner uses it at the door. Everything else is optional.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _marketingOptIn = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentSessionProvider).profile;
    _name.text = profile?.fullName ?? '';
    _email.text = profile?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _isValid => _name.text.trim().length >= 2;

  Future<void> _save() async {
    setState(() => _busy = true);

    try {
      await ref.read(accountRepositoryProvider).updateProfile(
            fullName: _name.text,
            email: _email.text,
            marketingOptIn: _marketingOptIn,
          );

      // The router watches the session: once onboarding is complete it moves on.
      await ref.read(sessionProvider.notifier).refresh();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(sessionProvider.notifier).signOut(
          deviceToken: ref.read(pushTokenProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final phone = ref.watch(currentSessionProvider).profile?.phone;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 28),
            Text(
              'Almost there',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: brand.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us your name so our kitchen and delivery partner know who the order is for.',
              style: TextStyle(fontSize: 15, height: 1.45, color: brand.inkMuted),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                helperText: 'We will email your bill and order updates.',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            if (phone != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: brand.surfaceMuted,
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: brand.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$phone is verified',
                        style: TextStyle(fontSize: 14, color: brand.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: _marketingOptIn,
              onChanged: (value) => setState(() => _marketingOptIn = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Send me offers and new dish alerts'),
              subtitle: Text(
                'You can change this any time in your profile.',
                style: TextStyle(fontSize: 13, color: brand.inkMuted),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy || !_isValid ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Start ordering'),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Use a different number'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
