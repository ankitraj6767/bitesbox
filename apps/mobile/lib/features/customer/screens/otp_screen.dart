import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';

/// One-time code entry.
///
/// Supabase enforces the real resend throttle; the countdown here just stops the
/// customer tapping a button that will be refused.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.phone, super.key});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _codeLength = 6;
  static const _resendSeconds = 30;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // The keyboard should already be up: the customer is holding an SMS.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != _codeLength) {
      setState(() => _error = 'Enter the $_codeLength-digit code.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: widget.phone, token: code);

      // Re-resolve identity, permissions and branch scope; the router then sends
      // this user to whichever shell their role belongs in.
      await ref.read(sessionProvider.notifier).refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'That code is incorrect or has expired.';
      });
      AppFeedback.showError(context, error);
      _controller.clear();
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);

    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      if (!mounted) return;
      AppFeedback.showInfo(context, 'We have sent a new code.');
      _startCountdown();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Enter the code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: brand.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 15, height: 1.45, color: brand.inkMuted),
                  children: [
                    const TextSpan(text: 'Sent to '),
                    TextSpan(
                      text: widget.phone,
                      style: TextStyle(fontWeight: FontWeight.w600, color: brand.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: _codeLength,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '––––––',
                  hintStyle: TextStyle(
                    fontSize: 26,
                    letterSpacing: 12,
                    color: brand.inkMuted.withValues(alpha: 0.4),
                  ),
                  errorText: _error,
                ),
                onChanged: (value) {
                  setState(() => _error = null);
                  // Submit as soon as the code is complete: no extra tap needed.
                  if (value.length == _codeLength) _verify();
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _verifying ? null : _verify,
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify and continue'),
              ),
              const SizedBox(height: 18),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Resend code in ${_secondsLeft}s',
                        style: TextStyle(fontSize: 14, color: brand.inkMuted),
                      )
                    : TextButton(
                        onPressed: _resending ? null : _resend,
                        child: Text(_resending ? 'Sending…' : 'Resend code'),
                      ),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Change number'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
