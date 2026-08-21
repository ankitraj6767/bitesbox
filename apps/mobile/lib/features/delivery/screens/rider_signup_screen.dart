import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';

/// Public delivery-partner application.
///
/// This collects the identity and vehicle details needed to create the admin
/// application. Identity documents are intentionally uploaded only after the
/// account exists, from [RiderOnboardingScreen], so each file is stored under
/// the applicant's own Supabase Storage prefix.
class RiderSignupScreen extends ConsumerStatefulWidget {
  const RiderSignupScreen({super.key});

  @override
  ConsumerState<RiderSignupScreen> createState() => _RiderSignupScreenState();
}

class _RiderSignupScreenState extends ConsumerState<RiderSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _vehicleNumber = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Bakhtiyarpur');
  final _state = TextEditingController(text: 'Bihar');
  final _postalCode = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();

  String _vehicleType = 'MOTORCYCLE';
  bool _obscurePassword = true;
  bool _busy = false;

  static const _vehicleLabels = <String, String>{
    'BICYCLE': 'Bicycle',
    'SCOOTER': 'Scooter',
    'MOTORCYCLE': 'Motorcycle',
    'CAR': 'Car',
    'ON_FOOT': 'On foot',
  };

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _password,
      _confirmPassword,
      _vehicleNumber,
      _address,
      _city,
      _state,
      _postalCode,
      _emergencyName,
      _emergencyPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  String? _phoneError(String? value, {bool required = false}) {
    if ((value ?? '').trim().isEmpty) {
      return required ? 'Mobile number is required' : null;
    }
    return AuthRepository.isValidIndianMobile(value!)
        ? null
        : 'Enter a valid 10-digit Indian mobile number';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirmPassword.text) {
      AppFeedback.showInfo(context, 'Passwords do not match.');
      return;
    }

    setState(() => _busy = true);

    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.signUpRider(
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        vehicleType: _vehicleType,
        vehicleNumber: _vehicleNumber.text,
        addressLine1: _address.text,
        city: _city.text,
        state: _state.text,
        postalCode: _postalCode.text,
        emergencyContactName: _emergencyName.text,
        emergencyContactPhone: _emergencyPhone.text,
      );

      // The function confirms the email so the new rider can enter the app
      // immediately and upload documents. The admin approval still gates duty.
      await auth.signInWithEmail(email: _email.text, password: _password.text);
      await ref.read(sessionProvider.notifier).refresh();
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: const Text('Become a delivery partner')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Deliver with Bites Box',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: brand.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apply in a few minutes. After you submit your documents, the outlet team will review and approve your account before you can go online.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: brand.inkMuted,
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Your details'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: _decoration(
                  'Full name *',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (value) => _required(value, 'Full name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: _decoration(
                  'Work email *',
                  icon: Icons.alternate_email_rounded,
                ),
                validator: (value) {
                  final required = _required(value, 'Email');
                  if (required != null) return required;
                  return RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value!.trim())
                      ? null
                      : 'Enter a valid email address';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                decoration: _decoration(
                  'Mobile number *',
                  icon: Icons.phone_outlined,
                  hint: '98765 43210',
                ).copyWith(prefixText: '+91 ', counterText: ''),
                validator: (value) => _phoneError(value, required: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration:
                    _decoration(
                      'Password *',
                      icon: Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                validator: (value) => (value ?? '').length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscurePassword,
                decoration: _decoration(
                  'Confirm password *',
                  icon: Icons.lock_reset_outlined,
                ),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Confirm your password' : null,
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Vehicle and area'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: _decoration(
                  'Vehicle type *',
                  icon: Icons.two_wheeler_outlined,
                ),
                items: _vehicleLabels.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _vehicleType = value ?? _vehicleType),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleNumber,
                textCapitalization: TextCapitalization.characters,
                decoration: _decoration(
                  'Vehicle registration (optional)',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Current address *',
                  icon: Icons.home_outlined,
                ),
                validator: (value) => _required(value, 'Address'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: _decoration('City *'),
                      validator: (value) => _required(value, 'City'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _postalCode,
                      keyboardType: TextInputType.number,
                      decoration: _decoration('PIN code *'),
                      validator: (value) =>
                          (value ?? '').trim().length < 6 ? 'Enter PIN' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _state,
                decoration: _decoration('State *'),
                validator: (value) => _required(value, 'State'),
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Emergency contact (optional)'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emergencyName,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Contact name',
                  icon: Icons.contact_phone_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyPhone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                decoration: _decoration(
                  'Contact mobile',
                  hint: '98765 43210',
                ).copyWith(prefixText: '+91 ', counterText: ''),
                validator: (value) => _phoneError(value),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit application'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.push(Routes.staffSignIn),
                  child: const Text('Already have a work account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}
