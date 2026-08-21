import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';

/// Email and password sign-in for kitchen tablets and shared devices, where
/// waiting for an SMS on someone's personal phone is impractical.
///
/// The shell a staff member lands in is decided by their roles in the database,
/// not by this screen.
class StaffSignInScreen extends ConsumerStatefulWidget {
  const StaffSignInScreen({super.key});

  @override
  ConsumerState<StaffSignInScreen> createState() => _StaffSignInScreenState();
}

class _StaffSignInScreenState extends ConsumerState<StaffSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _email.text.contains('@') && _password.text.trim().length >= 6;

  Future<void> _signIn() async {
    setState(() => _busy = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: _email.text, password: _password.text);

      await ref.read(sessionProvider.notifier).refresh();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: const Text('Staff sign-in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 8),
            Text(
              'Sign in with your work account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: brand.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For kitchen, delivery and management accounts. Customers should use their mobile number instead.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: brand.inkMuted,
              ),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Work email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _isValid ? _signIn() : null,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy || !_isValid ? null : _signIn,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 18),
            Text(
              'Forgotten your password? Ask your manager to send a reset link from the admin dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: brand.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push(Routes.riderSignup),
              child: const Text('New delivery partner? Apply here'),
            ),
          ],
        ),
      ),
    );
  }
}
