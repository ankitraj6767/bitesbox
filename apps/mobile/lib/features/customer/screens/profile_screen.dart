import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../providers/customer_providers.dart';

/// Edit profile and notification preferences.
///
/// The phone number is the account identity and is changed by signing in with a
/// different number, not by editing a field here.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  late bool _marketingOptIn;
  bool _push = true;
  bool _sms = true;
  bool _whatsapp = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentSessionProvider).profile;
    _name.text = profile?.fullName ?? '';
    _email.text = profile?.email ?? '';
    _marketingOptIn = profile?.marketingOptIn ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      AppFeedback.showInfo(context, 'Please enter your name.');
      return;
    }

    setState(() => _busy = true);

    try {
      await ref.read(accountRepositoryProvider).updateProfile(
            fullName: _name.text,
            email: _email.text,
            marketingOptIn: _marketingOptIn,
            pushEnabled: _push,
            smsEnabled: _sms,
            whatsappEnabled: _whatsapp,
          );

      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Profile updated.');
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
    final session = ref.watch(currentSessionProvider);
    final profile = session.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              helperText: 'Used for bills and order receipts',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            enabled: false,
            controller: TextEditingController(text: profile?.phone ?? ''),
            decoration: InputDecoration(
              labelText: 'Mobile number',
              helperText: 'Sign in with a different number to change this',
              prefixIcon: const Icon(Icons.phone_outlined),
              suffixIcon: Icon(Icons.verified_rounded, color: brand.success, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'How should we reach you?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Order updates are always sent. These control everything else.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: brand.inkMuted),
          ),
          SwitchListTile.adaptive(
            value: _push,
            contentPadding: EdgeInsets.zero,
            title: const Text('Push notifications'),
            onChanged: (value) => setState(() => _push = value),
          ),
          SwitchListTile.adaptive(
            value: _sms,
            contentPadding: EdgeInsets.zero,
            title: const Text('SMS'),
            onChanged: (value) => setState(() => _sms = value),
          ),
          SwitchListTile.adaptive(
            value: _whatsapp,
            contentPadding: EdgeInsets.zero,
            title: const Text('WhatsApp'),
            onChanged: (value) => setState(() => _whatsapp = value),
          ),
          Divider(height: 24, color: brand.hairline),
          SwitchListTile.adaptive(
            value: _marketingOptIn,
            contentPadding: EdgeInsets.zero,
            title: const Text('Offers and new dish alerts'),
            subtitle: Text(
              'Occasional messages about discounts and additions to the menu.',
              style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
            ),
            onChanged: (value) => setState(() => _marketingOptIn = value),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save changes'),
          ),
          const SizedBox(height: 24),
          if (session.roles.isNotEmpty) ...[
            Text(
              'Your access',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: brand.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: session.roles
                  .map(
                    (grant) => Chip(
                      label: Text(grant.role.label),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
