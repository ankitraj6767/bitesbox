import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/customer_copy.dart';

import '../../../core/auth/session.dart' show UserProfile;
import '../../../core/errors/app_error.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/feedback.dart';
import '../../../shared/widgets/states.dart';
import '../providers/customer_providers.dart';
import '../widgets/taste_passport_editor.dart';

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

  bool _preferencesReady = false;
  String? _hydratedUserId;
  bool _marketingOptIn = false;
  bool _push = true;
  bool _sms = true;
  bool _whatsapp = false;
  bool _marketingChanged = false;
  bool _pushChanged = false;
  bool _smsChanged = false;
  bool _whatsappChanged = false;
  bool _busy = false;
  String _language = 'en';
  bool _languageChanged = false;

  @override
  void initState() {
    super.initState();
    _hydrate(ref.read(currentSessionProvider).profile);
  }

  void _hydrate(UserProfile? profile, {bool force = false}) {
    if (profile == null || (!force && _hydratedUserId == profile.id)) return;
    _hydratedUserId = profile.id;
    _name.text = profile.fullName ?? '';
    _email.text = profile.email ?? '';
    _marketingOptIn = profile.marketingOptIn;
    _push = profile.pushEnabled;
    _sms = profile.smsEnabled;
    _whatsapp = profile.whatsappEnabled;
    _language = profile.preferredLanguage;
    _marketingChanged = false;
    _pushChanged = false;
    _smsChanged = false;
    _whatsappChanged = false;
    _languageChanged = false;
    _preferencesReady = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      AppFeedback.showInfo(
        context,
        context.customerText("Please enter your name."),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(
            fullName: _name.text,
            email: _email.text,
            marketingOptIn: _marketingChanged ? _marketingOptIn : null,
            pushEnabled: _pushChanged ? _push : null,
            smsEnabled: _smsChanged ? _sms : null,
            whatsappEnabled: _whatsappChanged ? _whatsapp : null,
            preferredLanguage: _languageChanged ? _language : null,
          );
      final currentProfile = ref.read(currentSessionProvider).profile!;
      final savedProfile = currentProfile.copyWith(
        fullName: _name.text.trim(),
        email: _email.text.trim().isEmpty
            ? null
            : _email.text.trim().toLowerCase(),
        marketingOptIn: _marketingChanged ? _marketingOptIn : null,
        pushEnabled: _pushChanged ? _push : null,
        smsEnabled: _smsChanged ? _sms : null,
        whatsappEnabled: _whatsappChanged ? _whatsapp : null,
        preferredLanguage: _languageChanged ? _language : null,
      );
      ref.read(sessionProvider.notifier).updateProfile(savedProfile);
      if (!mounted) return;
      _hydrate(savedProfile, force: true);
      AppFeedback.showSuccess(
        context,
        context.customerText("Profile updated."),
      );
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
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentSessionProvider);
    final profile = session.profile;

    if (profile != null &&
        (!_preferencesReady || profile.id != _hydratedUserId)) {
      _hydrate(profile, force: true);
    }

    if (!session.authenticated || profile == null || !_preferencesReady) {
      final sessionState = ref.watch(sessionProvider);
      return Scaffold(
        appBar: AppBar(title: Text(l10n.yourProfile)),
        body: sessionState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            error: error,
            onRetry: () => ref.read(sessionProvider.notifier).refresh(),
          ),
          data: (loadedSession) => loadedSession.authenticated
              ? AppErrorState(
                  error: AppError(
                    code: 'PROFILE_UNAVAILABLE',
                    message: context.customerText(
                      "Your profile could not be loaded.",
                    ),
                  ),
                  onRetry: () => ref.read(sessionProvider.notifier).refresh(),
                )
              : Center(
                  child: Text(
                    context.customerText("Sign in to view your profile."),
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.yourProfile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.customerText("Full name"),
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.customerText("Email"),
              helperText: context.customerText(
                "Used for bills and order receipts",
              ),
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            enabled: false,
            controller: TextEditingController(text: profile.phone),
            decoration: InputDecoration(
              labelText: context.customerText("Mobile number"),
              helperText: context.customerText(
                "Sign in with a different number to change this",
              ),
              prefixIcon: const Icon(Icons.phone_outlined),
              suffixIcon: Icon(
                Icons.verified_rounded,
                color: brand.success,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: InputDecoration(
              labelText: l10n.language,
              prefixIcon: const Icon(Icons.translate_rounded),
            ),
            items: [
              DropdownMenuItem(value: 'en', child: Text(l10n.english)),
              DropdownMenuItem(value: 'hi', child: Text(l10n.hindi)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _language = value ?? 'en';
                    _languageChanged = _language != profile.preferredLanguage;
                  }),
          ),
          const SizedBox(height: 24),
          const TastePassportEditor(),
          const SizedBox(height: 20),
          Text(
            context.customerText('How should we reach you?'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.orderCriticalMessages,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: brand.inkMuted,
            ),
          ),
          SwitchListTile.adaptive(
            value: _push,
            contentPadding: EdgeInsets.zero,
            title: Text(context.customerText("Push notifications")),
            onChanged: (value) => setState(() {
              _push = value;
              _pushChanged = true;
            }),
          ),
          SwitchListTile.adaptive(
            value: _sms,
            contentPadding: EdgeInsets.zero,
            title: Text(context.customerText("SMS")),
            onChanged: (value) => setState(() {
              _sms = value;
              _smsChanged = true;
            }),
          ),
          SwitchListTile.adaptive(
            value: _whatsapp,
            contentPadding: EdgeInsets.zero,
            title: Text(context.customerText("WhatsApp")),
            onChanged: (value) => setState(() {
              _whatsapp = value;
              _whatsappChanged = true;
            }),
          ),
          Divider(height: 24, color: brand.hairline),
          SwitchListTile.adaptive(
            value: _marketingOptIn,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.offersConsent),
            subtitle: Text(
              context.customerText(
                'Occasional messages about discounts and additions to the menu.',
              ),
              style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
            ),
            onChanged: (value) => setState(() {
              _marketingOptIn = value;
              _marketingChanged = true;
            }),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _busy ? context.customerText("Saving…") : l10n.saveChanges,
            ),
          ),
          const SizedBox(height: 24),
          if (session.roles.isNotEmpty) ...[
            Text(
              context.customerText('Your access'),
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
                      label: Text(context.customerText(grant.role.label)),
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
