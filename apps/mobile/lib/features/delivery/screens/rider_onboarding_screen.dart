import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/image_upload_service.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/delivery_models.dart';
import '../providers/delivery_providers.dart';

/// Rider onboarding: upload the documents the outlet requires, and see where each
/// one stands.
///
/// The list is not hard-coded. `my_rider_onboarding()` returns what this outlet
/// asks for, so a bicycle rider is not asked for a vehicle RC and a change in
/// local rules does not need an app release.
///
/// A rejected document is shown with the reviewer's reason. There is no state in
/// which a rider sees a red mark and has nothing to act on.
class RiderOnboardingScreen extends ConsumerWidget {
  const RiderOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(riderOnboardingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Get set up')),
      body: AsyncValueView<RiderOnboarding>(
        value: onboarding,
        onRetry: () => ref.invalidate(riderOnboardingProvider),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(riderOnboardingProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              _ProgressCard(onboarding: data),
              const SizedBox(height: 14),
              if (data.isBlocked) ...[
                AppNotice(
                  tone: NoticeTone.critical,
                  message: data.suspendedReason ??
                      data.rejectionReason ??
                      'Your account is on hold. Please speak to your manager.',
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'YOUR DOCUMENTS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: context.brand.inkMuted,
                ),
              ),
              const SizedBox(height: 10),
              ...data.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DocumentTile(step: step, locked: data.isBlocked),
                ),
              ),
              const SizedBox(height: 8),
              _ContactCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.onboarding});

  final RiderOnboarding onboarding;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final total = onboarding.requiredCount;
    final done = onboarding.approvedRequiredCount;
    final fraction = total == 0 ? 0.0 : done / total;

    final tone = switch (onboarding.onboardingStatus) {
      'ACTIVE' => brand.success,
      'SUSPENDED' || 'REJECTED' => brand.error,
      'VERIFIED' || 'DOCUMENTS_SUBMITTED' => brand.secondary,
      _ => brand.warning,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.humanise(onboarding.onboardingStatus),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: tone,
                  ),
                ),
              ),
              if (total > 0)
                Text(
                  '$done of $total approved',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: brand.inkMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: brand.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
              // Screen readers get the count above; the bar is decoration.
              semanticsLabel: 'Onboarding progress',
              semanticsValue: '$done of $total documents approved',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            onboarding.headline,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: brand.ink),
          ),
          if (onboarding.partnerCode != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 16, color: brand.inkMuted),
                const SizedBox(width: 6),
                Text(
                  'Partner code ${onboarding.partnerCode}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: brand.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentTile extends ConsumerStatefulWidget {
  const _DocumentTile({required this.step, required this.locked});

  final OnboardingStep step;
  final bool locked;

  @override
  ConsumerState<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends ConsumerState<_DocumentTile> {
  bool _busy = false;

  Future<void> _upload() async {
    final step = widget.step;
    final type = step.type;

    if (type == null) {
      // The server asked for a type this build does not know about. Saying so is
      // better than showing a button that cannot work.
      AppFeedback.showInfo(
        context,
        'Update the app to upload ${step.label}.',
      );
      return;
    }

    final details = await _askForDetails(type);
    if (details == null || !mounted) return;

    setState(() => _busy = true);

    try {
      await ref.read(riderOnboardingProvider.notifier).submit(
            type: type,
            file: details.file,
            documentNumber: details.number,
            expiresOn: details.expiresOn,
          );

      if (!mounted) return;
      AppFeedback.showSuccess(context, '${step.label} submitted for review');
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Camera or gallery, then the number and expiry the reviewer needs.
  Future<_DocumentDraft?> _askForDetails(RiderDocumentType type) async {
    final uploader = ref.read(imageUploadServiceProvider);

    File? file;

    if (type.isPortrait) {
      file = await uploader.pickPortrait();
    } else {
      final source = await AppFeedback.sheet<ImageSourceChoice>(
        context,
        builder: (sheetContext) => _SourceSheet(label: type.label),
      );

      if (source == null) return null;
      file = await uploader.pick(source);
    }

    if (file == null || !mounted) return null;

    // A photo is enough for a face; a licence needs its number and expiry so the
    // expiry job can warn before it lapses.
    if (type.isPortrait) return _DocumentDraft(file: file);

    final meta = await AppFeedback.sheet<_DocumentMeta>(
      context,
      builder: (sheetContext) => _MetaSheet(type: type),
    );

    if (meta == null) return null;

    return _DocumentDraft(
      file: file,
      number: meta.number,
      expiresOn: meta.expiresOn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final step = widget.step;
    final doc = step.document;
    final status = doc?.effectiveStatus;

    final (Color tone, IconData icon) = switch (status) {
      RiderDocumentStatus.approved => (brand.success, Icons.check_circle_rounded),
      RiderDocumentStatus.pending => (brand.secondary, Icons.schedule_rounded),
      RiderDocumentStatus.rejected => (brand.error, Icons.error_rounded),
      RiderDocumentStatus.expired => (brand.error, Icons.event_busy_rounded),
      null => (
          step.isRequired ? brand.warning : brand.inkMuted,
          Icons.upload_file_rounded,
        ),
    };

    final canUpload = !widget.locked && status != RiderDocumentStatus.approved;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(
          color: status?.needsAction == true
              ? brand.error.withValues(alpha: 0.35)
              : brand.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            step.label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: brand.ink,
                            ),
                          ),
                        ),
                        if (!step.isRequired) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Optional',
                            style: TextStyle(fontSize: 11, color: brand.inkMuted),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.statusLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
              if (canUpload)
                _busy
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                    : TextButton(
                        onPressed: _upload,
                        child: Text(step.isUploaded ? 'Replace' : 'Upload'),
                      ),
            ],
          ),
          if (doc?.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: brand.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                doc!.rejectionReason!,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: brand.error),
              ),
            ),
          ] else if (doc == null && step.type != null) ...[
            const SizedBox(height: 8),
            Text(
              step.type!.hint,
              style: TextStyle(fontSize: 12, color: brand.inkMuted),
            ),
          ],
          if (doc?.expiresOn != null) ...[
            const SizedBox(height: 8),
            Text(
              doc!.isExpired
                  ? 'Expired on ${Fmt.day(doc.expiresOn!)}'
                  : 'Valid until ${Fmt.day(doc.expiresOn!)}',
              style: TextStyle(
                fontSize: 12,
                color: doc.isExpired ? brand.error : brand.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the rider chose to upload, before it is sent.
class _DocumentDraft {
  const _DocumentDraft({required this.file, this.number, this.expiresOn});

  final File file;
  final String? number;
  final DateTime? expiresOn;
}

class _DocumentMeta {
  const _DocumentMeta({this.number, this.expiresOn});

  final String? number;
  final DateTime? expiresOn;
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: label,
              subtitle: 'Photograph it now, or pick a photo you already have.',
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              subtitle: const Text('Best results — hold it flat in good light'),
              onTap: () => Navigator.of(context).pop(ImageSourceChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSourceChoice.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

/// Number and expiry. Both optional in the database, but the expiry is what makes
/// `job_rider_document_expiry` able to warn before a licence lapses, so it is
/// asked for rather than skipped.
class _MetaSheet extends StatefulWidget {
  const _MetaSheet({required this.type});

  final RiderDocumentType type;

  @override
  State<_MetaSheet> createState() => _MetaSheetState();
}

class _MetaSheetState extends State<_MetaSheet> {
  final _number = TextEditingController();
  DateTime? _expiry;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  bool get _wantsExpiry => switch (widget.type) {
        RiderDocumentType.drivingLicence ||
        RiderDocumentType.insurance ||
        RiderDocumentType.policeVerification =>
          true,
        _ => false,
      };

  Future<void> _pickExpiry() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year + 1, now.month, now.day),
      // An already-expired document is refused by the server, so the picker does
      // not offer the past.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30),
      helpText: 'Valid until',
    );

    if (picked != null) setState(() => _expiry = picked);
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              title: widget.type.label,
              subtitle: 'A couple of details so the team can check it.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _number,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              decoration: InputDecoration(
                labelText: '${widget.type.label} number',
                hintText: 'Optional',
              ),
            ),
            if (_wantsExpiry) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickExpiry,
                borderRadius: BorderRadius.circular(brand.radiusSm),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Valid until'),
                  child: Text(
                    _expiry == null ? 'Choose a date' : Fmt.day(_expiry!),
                    style: TextStyle(
                      fontSize: 14.5,
                      color: _expiry == null ? brand.inkMuted : brand.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We will remind you before it expires so you never lose a shift to '
                'lapsed paperwork.',
                style: TextStyle(fontSize: 12, height: 1.4, color: brand.inkMuted),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _DocumentMeta(
                  number: _number.text.trim().isEmpty ? null : _number.text.trim(),
                  expiresOn: _expiry,
                ),
              ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              child: const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The contact details a rider owns. Everything else on their record is corrected
/// by a manager, which is audited — a rider was previously able to set their own
/// onboarding status and zero their cash-in-hand through a table policy.
class _ContactCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surfaceMuted,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact and payout details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Alternate number, emergency contact and UPI id.',
                  style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showRiderContactSheet(context, ref),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

/// Editable contact fields. Shared with the profile screen.
Future<void> showRiderContactSheet(BuildContext context, WidgetRef ref) async {
  await AppFeedback.sheet<void>(
    context,
    builder: (sheetContext) => const _ContactSheet(),
  );
}

class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet();

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _alternatePhone = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _upi = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _alternatePhone.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);

    try {
      await ref.read(riderOnboardingProvider.notifier).updateContactDetails(
            alternatePhone: _alternatePhone.text,
            emergencyContactName: _emergencyName.text,
            emergencyContactPhone: _emergencyPhone.text,
            upiId: _upi.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Details saved');
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              title: 'Your details',
              subtitle: 'Leave a field blank to keep what is already saved.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _alternatePhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [LengthLimitingTextInputFormatter(15)],
              decoration: const InputDecoration(labelText: 'Alternate phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Emergency contact name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [LengthLimitingTextInputFormatter(15)],
              decoration: const InputDecoration(labelText: 'Emergency contact phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upi,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'UPI id',
                hintText: 'name@bank',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your name, phone, vehicle and delivery limits are set by your '
              'manager. Ask them to correct anything else.',
              style: TextStyle(fontSize: 12, height: 1.4, color: brand.inkMuted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
