import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/routing/routes.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/launcher.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/live_map.dart';
import '../../../shared/widgets/states.dart';
import '../data/delivery_models.dart';
import '../data/delivery_repository.dart';
import '../providers/delivery_providers.dart';
import 'rider_shell.dart';

/// One delivery, start to finish.
///
/// The screen shows exactly one primary action at a time, derived from the
/// assignment status the server reports. Nothing is optimistic: each step is a
/// round trip, because a rider who *thinks* they picked up an order that the
/// kitchen has not released causes a real operational problem.
class RiderDeliveryScreen extends ConsumerStatefulWidget {
  const RiderDeliveryScreen({required this.assignmentId, super.key});

  final String assignmentId;

  @override
  ConsumerState<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends ConsumerState<RiderDeliveryScreen> {
  bool _busy = false;
  bool _finished = false;

  RiderDashboardController get _controller =>
      ref.read(riderDashboardProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      // Wrong-code errors carry the attempts that remain; showing that stops a
      // rider burning through the rate limit blind.
      if (mounted) AppFeedback.showError(context, _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Adds the server's remaining-attempts hint to a verification failure.
  static Object _describe(Object error) {
    final appError = error is AppError ? error : AppError.from(error);
    final left = appError.details?['attempts_left'];

    if (left is int && left >= 0) {
      return AppError(
        code: appError.code,
        message: '${appError.message} '
            '$left attempt${left == 1 ? '' : 's'} left before this locks.',
        details: appError.details,
        cause: appError.cause,
      );
    }

    return appError;
  }

  // ── Steps ──

  Future<void> _accept() => _run(
        () => _controller.respond(assignmentId: widget.assignmentId, accept: true),
      );

  Future<void> _decline() async {
    final reason = await showRiderReasonSheet(
      context,
      title: 'Why are you declining?',
      subtitle: 'Operations will see this and reassign the order.',
      reasons: DeliveryRepository.declineReasons,
      confirmLabel: 'Decline delivery',
    );

    if (reason == null || !mounted) return;

    await _run(() async {
      await _controller.respond(
        assignmentId: widget.assignmentId,
        accept: false,
        reason: reason,
      );
      if (mounted) {
        _finished = true;
        context.go(Routes.rider);
        AppFeedback.showInfo(context, 'Declined. It has gone back to dispatch.');
      }
    });
  }

  Future<void> _arrivedAtStore() =>
      _run(() => _controller.arrivedAtStore(widget.assignmentId));

  Future<void> _verifyPickup(DeliveryAssignment job) async {
    final code = await AppFeedback.sheet<String>(
      context,
      builder: (_) => _CodeEntrySheet(
        title: 'Verify the pickup code',
        subtitle: 'Read the code printed on the kitchen ticket for '
            '${job.order.orderNumber}. This makes sure you leave with the right parcel.',
        actionLabel: 'Confirm pickup',
        length: 6,
      ),
    );

    if (code == null || !mounted) return;

    await _run(() async {
      final result = await _controller.verifyPickup(
        assignmentId: widget.assignmentId,
        code: code,
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      AppFeedback.showSuccess(
        context,
        result.codAmount > 0
            ? 'Picked up. Collect ${Fmt.moneySmart(result.codAmount)} on delivery.'
            : 'Picked up. Head to the customer.',
      );
    });
  }

  Future<void> _arrivedAtCustomer() =>
      _run(() => _controller.arrivedAtCustomer(widget.assignmentId));

  Future<void> _complete(DeliveryAssignment job) async {
    final result = await AppFeedback.sheet<_CompletionInput>(
      context,
      builder: (_) => _CompleteDeliverySheet(job: job),
    );

    if (result == null || !mounted) return;

    await _run(() async {
      await _controller.completeDelivery(
        assignmentId: widget.assignmentId,
        otp: result.otp,
        cashCollected: result.cashCollected,
        note: result.note,
        proofPhotoPath: result.proofPhotoPath,
      );

      if (!mounted) return;

      _finished = true;
      HapticFeedback.heavyImpact();
      context.go(Routes.rider);
      AppFeedback.showSuccess(context, 'Delivered. Nice work.');
    });
  }

  Future<void> _reportProblem() async {
    final reason = await showRiderReasonSheet(
      context,
      title: 'What went wrong?',
      subtitle: 'Operations will pick this up straight away and contact the customer.',
      reasons: DeliveryRepository.failureReasons,
      confirmLabel: 'Report failed delivery',
    );

    if (reason == null || !mounted) return;

    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Mark this delivery as failed?',
      message: 'The order will be handed back to operations. Only do this if you '
          'genuinely cannot complete the delivery.',
      confirmLabel: 'Yes, report it',
      cancelLabel: 'Go back',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    await _run(() async {
      await _controller.failDelivery(
        assignmentId: widget.assignmentId,
        reason: reason,
      );
      if (mounted) {
        _finished = true;
        context.go(Routes.rider);
        AppFeedback.showInfo(context, 'Reported. Operations will take it from here.');
      }
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final dashboard = ref.watch(riderDashboardProvider);

    // Keep publishing GPS for as long as this screen is open and a job is live.
    ref.watch(riderLocationPublisherProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.rider),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to deliveries',
        ),
        title: const Text('Delivery'),
      ),
      body: AsyncValueView<RiderDashboard>(
        value: dashboard,
        onRetry: () => ref.invalidate(riderDashboardProvider),
        data: (data) {
          final matches = data.active
              .where((assignment) => assignment.assignmentId == widget.assignmentId);

          if (matches.isEmpty) return _ClosedJobPanel(finished: _finished);
          final job = matches.first;

          return RefreshIndicator(
            color: brand.primary,
            onRefresh: () => _controller.refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _JobHeader(job: job),
                const SizedBox(height: 14),
                _StepTracker(job: job),
                const SizedBox(height: 14),
                _RouteMap(job: job),
                const SizedBox(height: 14),
                _StopCard(job: job),
                if (job.order.isCod) ...[
                  const SizedBox(height: 12),
                  _CodBanner(amount: job.order.codAmount, collected: false),
                ],
                const SizedBox(height: 12),
                _ParcelCard(job: job),
                if ((job.order.instructions ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppNotice(
                    tone: NoticeTone.info,
                    icon: Icons.edit_note_rounded,
                    message: job.order.instructions!,
                  ),
                ],
                const SizedBox(height: 18),
                _PrimaryAction(
                  job: job,
                  busy: _busy,
                  onAccept: _accept,
                  onArrivedStore: _arrivedAtStore,
                  onVerifyPickup: () => _verifyPickup(job),
                  onArrivedCustomer: _arrivedAtCustomer,
                  onComplete: () => _complete(job),
                ),
                const SizedBox(height: 10),
                if (job.isOffer)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _busy ? null : _decline,
                      style: TextButton.styleFrom(foregroundColor: brand.inkMuted),
                      child: const Text('I cannot take this one'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _reportProblem,
                      style: TextButton.styleFrom(foregroundColor: brand.error),
                      icon: const Icon(Icons.report_problem_outlined, size: 18),
                      label: const Text('I cannot complete this delivery'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────────── pieces ─────────────────────────────

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.job});

  final DeliveryAssignment job;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final order = job.order;

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
                  order.orderNumber,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: brand.ink,
                  ),
                ),
              ),
              AppPill(
                label: job.statusLabel,
                background: brand.secondary.withValues(alpha: 0.1),
                foreground: brand.secondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppPill(
                label: 'You earn ${Fmt.moneySmart(job.totalPayout)}',
                icon: Icons.payments_rounded,
                background: brand.success.withValues(alpha: 0.1),
                foreground: brand.success,
              ),
              if (order.distanceKm != null)
                AppPill(label: Fmt.distance(order.distanceKm), icon: Icons.route_rounded),
              if (order.promisedAt != null)
                AppPill(
                  label: 'Promised ${Fmt.time(order.promisedAt)}',
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The five stages of a delivery, so a rider can see where they are at a glance.
class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.job});

  final DeliveryAssignment job;

  static const _order = <String>[
    'OFFERED',
    'ACCEPTED',
    'AT_STORE',
    'PICKED_UP',
    'AT_CUSTOMER',
  ];

  static const _labels = <String>[
    'Assigned',
    'To store',
    'At store',
    'Picked up',
    'At customer',
  ];

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final index = _order.indexOf(job.status);
    final current = index < 0 ? _order.length - 1 : index;

    return Row(
      children: List.generate(_order.length * 2 - 1, (slot) {
        if (slot.isOdd) {
          final done = slot ~/ 2 < current;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: done ? brand.success : brand.hairline,
            ),
          );
        }

        final step = slot ~/ 2;
        final done = step < current;
        final active = step == current;
        final colour = done
            ? brand.success
            : active
                ? brand.primary
                : brand.hairline;

        return Column(
          children: [
            Container(
              width: active ? 20 : 16,
              height: active ? 20 : 16,
              decoration: BoxDecoration(
                color: done || active ? colour : brand.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colour, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 58,
              child: Text(
                _labels[step],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? brand.primary : brand.inkMuted,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// The rider's own position against the next stop.
///
/// Deliberately not a navigation surface: it is orientation only, and the big
/// Navigate button hands off to the phone's maps app, which does voice guidance,
/// traffic and lane detail far better than an embedded map could.
class _RouteMap extends ConsumerWidget {
  const _RouteMap({required this.job});

  final DeliveryAssignment job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fix = ref.watch(riderLastFixProvider);
    final toStore = job.navigatesToBranch;

    final destinationLat = toStore ? job.branch.latitude : job.order.latitude;
    final destinationLng = toStore ? job.branch.longitude : job.order.longitude;

    return LiveMap(
      height: 180,
      emptyMessage: 'No map location was saved for this stop.',
      points: [
        if (fix != null)
          MapPoint(
            id: 'me',
            latitude: fix.latitude,
            longitude: fix.longitude,
            label: 'You',
            kind: MapPointKind.rider,
          ),
        if (destinationLat != null && destinationLng != null)
          MapPoint(
            id: 'destination',
            latitude: destinationLat,
            longitude: destinationLng,
            label: toStore ? job.branch.name : (job.order.customerName ?? 'Customer'),
            kind: toStore ? MapPointKind.store : MapPointKind.customer,
            caption: job.order.distanceKm == null
                ? null
                : Fmt.distance(job.order.distanceKm),
          ),
      ],
    );
  }
}

/// Where to go next, with navigation and a call button.
class _StopCard extends StatelessWidget {
  const _StopCard({required this.job});

  final DeliveryAssignment job;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final toStore = job.navigatesToBranch;
    final order = job.order;

    final title = toStore ? job.branch.name : (order.customerName ?? 'Customer');
    final body = toStore ? (job.branch.address ?? 'Bites Box outlet') : order.address;
    final phone = toStore ? job.branch.phone : order.customerPhone;
    final latitude = toStore ? job.branch.latitude : order.latitude;
    final longitude = toStore ? job.branch.longitude : order.longitude;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            toStore ? 'PICK UP FROM' : 'DELIVER TO',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: brand.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          RiderWaypoint(
            icon: toStore ? Icons.storefront_rounded : Icons.location_on_rounded,
            title: title,
            body: body,
            tone: toStore ? brand.secondary : brand.primary,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => riderNavigate(
                    context,
                    latitude: latitude,
                    longitude: longitude,
                    label: title,
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navigate'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (phone ?? '').isEmpty ? null : () => Launcher.dial(phone),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(toStore ? 'Call outlet' : 'Call customer'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodBanner extends StatelessWidget {
  const _CodBanner({required this.amount, required this.collected});

  final double amount;
  final bool collected;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: brand.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_rupee_rounded, color: brand.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash on delivery',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: brand.warning,
                  ),
                ),
                Text(
                  'Collect exactly ${Fmt.moneySmart(amount)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: brand.ink,
                  ),
                ),
              ],
            ),
          ),
          if (collected) Icon(Icons.check_circle_rounded, color: brand.success, size: 22),
        ],
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.job});

  final DeliveryAssignment job;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final order = job.order;

    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(Icons.shopping_bag_outlined, size: 18, color: brand.inkMuted),
              const SizedBox(width: 8),
              Text(
                '${order.unitCount} item${order.unitCount == 1 ? '' : 's'} in this order',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: brand.ink,
                ),
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item.quantity} × ${item.label}',
                  style: TextStyle(fontSize: 13.5, height: 1.35, color: brand.inkMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.job,
    required this.busy,
    required this.onAccept,
    required this.onArrivedStore,
    required this.onVerifyPickup,
    required this.onArrivedCustomer,
    required this.onComplete,
  });

  final DeliveryAssignment job;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onArrivedStore;
  final VoidCallback onVerifyPickup;
  final VoidCallback onArrivedCustomer;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final (action, icon) = switch (job.status) {
      'OFFERED' => (onAccept, Icons.check_rounded),
      'ACCEPTED' => (onArrivedStore, Icons.storefront_rounded),
      'AT_STORE' => (onVerifyPickup, Icons.qr_code_scanner_rounded),
      'PICKED_UP' => (onArrivedCustomer, Icons.location_on_rounded),
      'AT_CUSTOMER' => (onComplete, Icons.done_all_rounded),
      _ => (null, Icons.hourglass_empty_rounded),
    };

    return RiderPrimaryButton(
      label: job.nextActionLabel,
      icon: icon,
      busy: busy,
      onPressed: action,
      colour: job.isAtCustomer ? context.brand.success : null,
    );
  }
}

class _ClosedJobPanel extends StatelessWidget {
  const _ClosedJobPanel({required this.finished});

  final bool finished;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: finished ? Icons.check_circle_outline_rounded : Icons.inventory_2_outlined,
      title: finished ? 'All done' : 'This delivery is closed',
      message: finished
          ? 'This delivery is complete and no longer needs your attention.'
          : 'It is either finished or has been reassigned. Check your list for '
              'anything still open.',
      action: FilledButton(
        onPressed: () => context.go(Routes.rider),
        child: const Text('Back to deliveries'),
      ),
    );
  }
}

// ───────────────────────────── sheets ─────────────────────────────

/// Numeric code entry, used for the pickup code.
class _CodeEntrySheet extends StatefulWidget {
  const _CodeEntrySheet({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.length = 6,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final int length;

  @override
  State<_CodeEntrySheet> createState() => _CodeEntrySheetState();
}

class _CodeEntrySheetState extends State<_CodeEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= 3;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            SheetHeader(title: widget.title, subtitle: widget.subtitle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: widget.length,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(counterText: '', hintText: '••••'),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RiderPrimaryButton(
                label: widget.actionLabel,
                onPressed: _valid
                    ? () => Navigator.of(context).pop(_controller.text.trim())
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionInput {
  const _CompletionInput({
    this.otp,
    this.cashCollected,
    this.note,
    this.proofPhotoPath,
  });

  final String? otp;
  final double? cashCollected;
  final String? note;

  /// Object key in the `delivery-proofs` bucket, already uploaded.
  final String? proofPhotoPath;
}

/// Final step: customer OTP, plus the exact cash for a COD order.
///
/// The rider cannot type a different amount than the server expects — the field
/// is prefilled and the server rejects a shortfall — so cash can never silently
/// go missing.
class _CompleteDeliverySheet extends ConsumerStatefulWidget {
  const _CompleteDeliverySheet({required this.job});

  final DeliveryAssignment job;

  @override
  ConsumerState<_CompleteDeliverySheet> createState() =>
      _CompleteDeliverySheetState();
}

class _CompleteDeliverySheetState extends ConsumerState<_CompleteDeliverySheet> {
  final _otp = TextEditingController();
  final _note = TextEditingController();
  bool _cashConfirmed = false;

  File? _proofFile;
  String? _proofPath;
  bool _uploadingProof = false;

  @override
  void dispose() {
    _otp.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_otp.text.trim().length < 3) return false;
    if (widget.job.order.isCod && !_cashConfirmed) return false;
    // A half-finished upload must not be submitted: the server would record a
    // path to an object that is not there yet.
    if (_uploadingProof) return false;
    return true;
  }

  /// Uploads immediately rather than at submit.
  ///
  /// The rider is standing at a doorstep on mobile data. Doing the upload while
  /// they are still typing the OTP means the slow part overlaps with the part that
  /// needs them, and a failure surfaces while there is still something to retry —
  /// rather than blocking the one action that closes the job.
  Future<void> _captureProof() async {
    final uploader = ref.read(imageUploadServiceProvider);

    final file = await uploader.pick(ImageSourceChoice.camera);
    if (file == null || !mounted) return;

    setState(() {
      _proofFile = file;
      _uploadingProof = true;
    });

    try {
      final path = await uploader.upload(
        file: file,
        bucket: StorageBuckets.deliveryProofs,
        // Keyed on the assignment so a retaken photo replaces the first attempt
        // instead of leaving an orphan the rider cannot delete.
        name: 'proof_${widget.job.assignmentId}',
      );

      if (!mounted) return;
      setState(() => _proofPath = path);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _proofFile = null;
        _proofPath = null;
      });
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final order = widget.job.order;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              SheetHeader(
                title: 'Complete the delivery',
                subtitle: 'Ask ${order.customerName ?? 'the customer'} for the '
                    '4-digit OTP in their app.',
              ),
              if (order.isCod)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: brand.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(brand.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collect ${Fmt.moneySmart(order.codAmount)} in cash',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: brand.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confirm you are holding the full amount. A shortfall is '
                          'refused and stays on your cash balance.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: brand.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          value: _cashConfirmed,
                          onChanged: (value) =>
                              setState(() => _cashConfirmed = value ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          title: Text(
                            'I have collected ${Fmt.moneySmart(order.codAmount)}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _otp,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    labelText: 'Delivery OTP',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ProofRow(
                  file: _proofFile,
                  uploading: _uploadingProof,
                  uploaded: _proofPath != null,
                  onCapture: _captureProof,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _note,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: 'Anything to note? (optional)',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'No OTP? Ask your manager — only they can complete a delivery '
                  'without it, and it is recorded against their name.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: brand.inkMuted),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RiderPrimaryButton(
                  label: 'Mark as delivered',
                  icon: Icons.done_all_rounded,
                  colour: brand.success,
                  onPressed: _valid
                      ? () => Navigator.of(context).pop(
                            _CompletionInput(
                              otp: _otp.text.trim(),
                              cashCollected: order.isCod ? order.codAmount : null,
                              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                              proofPhotoPath: _proofPath,
                            ),
                          )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



/// Proof-of-delivery photo.
///
/// Optional, and deliberately so. Requiring one would mean a rider with a dead
/// camera cannot close a job they have genuinely completed, and the OTP is already
/// the proof that matters. This is the extra evidence for the "it never arrived"
/// conversation three days later, and it is worth asking for without insisting.
class _ProofRow extends StatelessWidget {
  const _ProofRow({
    required this.file,
    required this.uploading,
    required this.uploaded,
    required this.onCapture,
  });

  final File? file;
  final bool uploading;
  final bool uploaded;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.surfaceMuted,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: file == null
                ? Container(
                    width: 46,
                    height: 46,
                    color: brand.hairline.withValues(alpha: 0.5),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: 20,
                      color: brand.inkMuted,
                    ),
                  )
                : Image.file(file!, width: 46, height: 46, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo of the handover',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  uploading
                      ? 'Uploading…'
                      : uploaded
                          ? 'Attached'
                          : 'Optional, but it settles disputes',
                  style: TextStyle(
                    fontSize: 12,
                    color: uploaded ? brand.success : brand.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (uploading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            TextButton(
              onPressed: onCapture,
              child: Text(uploaded ? 'Retake' : 'Take photo'),
            ),
        ],
      ),
    );
  }
}
