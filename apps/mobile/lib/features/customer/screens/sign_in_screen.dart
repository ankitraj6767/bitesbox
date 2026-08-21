import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';

/// Phone-first sign-in.
///
/// The OTP provider is configured server-side, so switching SMS vendors never
/// requires an app release. All this screen does is ask for a number.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => AuthRepository.isValidIndianMobile(_controller.text);

  Future<void> _sendCode() async {
    final phone = _controller.text.trim();

    if (!AuthRepository.isValidIndianMobile(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      context.push(Routes.verify, extra: phone);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => context.go(Routes.home),
                  child: const Text('Browse the menu'),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: brand.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                ),
                child: Icon(
                  Icons.lunch_dining_rounded,
                  size: 32,
                  color: brand.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to ${brand.name}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: brand.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your mobile number and we will send you a one-time code.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: brand.inkMuted,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                textInputAction: TextInputAction.done,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '98765 43210',
                  errorText: _error,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: brand.inkMuted,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending || !_isValid ? null : _sendCode,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send code'),
              ),
              const Spacer(),
              Text(
                'By continuing you agree to our terms of service and privacy policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: brand.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.push(Routes.staffSignIn),
                  child: const Text('Staff sign-in'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => context.push(Routes.riderSignup),
                  child: const Text(
                    'Want to deliver with us? Apply as a delivery partner',
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.push(Routes.policies),
                    child: const Text('Policies'),
                  ),
                  Text('·', style: TextStyle(color: brand.inkMuted)),
                  TextButton(
                    onPressed: () => context.push(Routes.faqs),
                    child: const Text('FAQs'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
