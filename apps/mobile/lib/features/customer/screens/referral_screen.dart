import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../providers/customer_providers.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({this.inviteCode, super.key});

  final String? inviteCode;

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  late final TextEditingController _code = TextEditingController(
    text: widget.inviteCode ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = context.brand;
    final session = ref.watch(currentSessionProvider);
    final summary = ref.watch(referralSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.referrals)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (!session.authenticated)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.enterReferralCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.referralSignInDescription),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push(
                        widget.inviteCode == null || widget.inviteCode!.isEmpty
                            ? Routes.signIn
                            : Routes.signInWithReferral(widget.inviteCode!),
                      ),
                      child: Text(l10n.signIn),
                    ),
                  ],
                ),
              ),
            )
          else
            summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => AppErrorState(
                error: error,
                onRetry: () => ref.invalidate(referralSummaryProvider),
              ),
              data: (data) {
                if (data == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.referralCode,
                              style: TextStyle(color: brand.inkMuted),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              data.code,
                              style: TextStyle(
                                fontSize: 26,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                                color: brand.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data.programActive
                                  ? l10n.referralShareDescription
                                  : l10n.referralUnavailable,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _copy(data.code),
                                  icon: const Icon(Icons.copy_rounded),
                                  label: Text(l10n.copyReferral),
                                ),
                                FilledButton.icon(
                                  onPressed: data.programActive
                                      ? () => _share(data.code, data.sharePath)
                                      : null,
                                  icon: const Icon(Icons.share_rounded),
                                  label: Text(l10n.shareReferral),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.referralCounts(
                                data.attributedCount,
                                data.rewardedCount,
                              ),
                              style: TextStyle(
                                color: brand.inkMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (data.programActive && data.terms != null) ...[
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.referralProgramTermsTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _ReferralTermRow(
                                label: l10n.referralYouEarn,
                                value: Fmt.moneySmart(
                                  data.terms!.referrerReward,
                                ),
                              ),
                              _ReferralTermRow(
                                label: l10n.referralFriendEarns,
                                value: Fmt.moneySmart(
                                  data.terms!.referredReward,
                                ),
                              ),
                              _ReferralTermRow(
                                label: l10n.referralMinimumOrder,
                                value: Fmt.moneySmart(
                                  data.terms!.minimumOrderAmount,
                                ),
                              ),
                              if (data.terms!.rewardExpiryDays != null)
                                _ReferralTermRow(
                                  label: l10n.referralRewardExpiry,
                                  value: l10n.daysCount(
                                    data.terms!.rewardExpiryDays!,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (data.referrals.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.referralYourInvites,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (
                                var index = 0;
                                index < data.referrals.length;
                                index++
                              ) ...[
                                if (index > 0) const Divider(height: 1),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    data.referrals[index].status == 'REWARDED'
                                        ? Icons.check_circle_rounded
                                        : Icons.card_giftcard_rounded,
                                    color:
                                        data.referrals[index].status ==
                                            'REWARDED'
                                        ? brand.success
                                        : brand.primary,
                                  ),
                                  title: Text(
                                    l10n.referralInviteNumber(index + 1),
                                  ),
                                  subtitle: Text(
                                    '${_referralStatusLabel(data.referrals[index].status, l10n)} · ${Fmt.dayTime(data.referrals[index].attributedAt)}',
                                  ),
                                  trailing:
                                      data.referrals[index].rewardedAt !=
                                              null &&
                                          data.referrals[index].referrerReward >
                                              0
                                      ? Text(
                                          Fmt.moneySmart(
                                            data
                                                .referrals[index]
                                                .referrerReward,
                                          ),
                                          style: TextStyle(
                                            color: brand.success,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TextField(
                      controller: _code,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.enterReferralCode,
                        prefixIcon: const Icon(Icons.card_giftcard_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed:
                          _busy ||
                              _code.text.trim().isEmpty ||
                              !data.programActive
                          ? null
                          : _apply,
                      child: Text(_busy ? l10n.applying : l10n.applyReferral),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      AppFeedback.showSuccess(
        context,
        AppLocalizations.of(context).referralCopied,
      );
    }
  }

  Future<void> _share(String code, String path) async {
    const base = String.fromEnvironment('WEB_BASE_URL');
    final link = base.isEmpty ? '' : '$base$path';
    final l10n = AppLocalizations.of(context);
    final message = link.isEmpty
        ? l10n.referralInviteMessageCode(code)
        : l10n.referralInviteMessageWithLink(code, link);
    final uri = Uri(scheme: 'sms', queryParameters: {'body': message});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        AppFeedback.showSuccess(
          context,
          AppLocalizations.of(context).inviteCopied,
        );
      }
    }
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      await ref.read(growthRepositoryProvider).attributeReferral(_code.text);
      ref.invalidate(referralSummaryProvider);
      if (mounted) {
        AppFeedback.showSuccess(
          context,
          AppLocalizations.of(context).referralApplied,
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ReferralTermRow extends StatelessWidget {
  const _ReferralTermRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: context.brand.inkMuted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

String _referralStatusLabel(String status, AppLocalizations l10n) =>
    switch (status) {
      'ATTRIBUTED' => l10n.referralStatusInvited,
      'QUALIFIED' => l10n.referralStatusQualified,
      'REWARDED' => l10n.referralStatusRewarded,
      'REVERSED' => l10n.referralStatusReversed,
      _ => status,
    };
