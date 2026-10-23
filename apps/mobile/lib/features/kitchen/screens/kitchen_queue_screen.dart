import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/kitchen_models.dart';
import '../data/kitchen_repository.dart';
import '../providers/kitchen_providers.dart';

/// The live kitchen board.
///
/// Four stages, one action per ticket. The elapsed timer ticks locally between
/// refreshes but is anchored to the server's own clock, so every tablet agrees.
class KitchenQueueScreen extends ConsumerStatefulWidget {
  const KitchenQueueScreen({super.key});

  @override
  ConsumerState<KitchenQueueScreen> createState() => _KitchenQueueScreenState();
}

class _KitchenQueueScreenState extends ConsumerState<KitchenQueueScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Only the timers redraw each second; the data itself comes from realtime.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final queue = ref.watch(kitchenQueueProvider);
    final stage = ref.watch(kitchenStageProvider);

    return AsyncValueView<KitchenQueue>(
      value: queue,
      onRetry: () => ref.read(kitchenQueueProvider.notifier).refresh(),
      data: (data) {
        final orders = data.forStage(stage);

        return Column(
          children: [
            _StageTabs(counts: data.counts, selected: stage),
            Expanded(
              child: orders.isEmpty
                  ? AppEmptyState(
                      title: switch (stage) {
                        KitchenStage.newOrders => 'No new orders',
                        KitchenStage.accepted => 'Nothing waiting to start',
                        KitchenStage.preparing => 'Nothing on the stove',
                        KitchenStage.ready => 'Nothing waiting for pickup',
                      },
                      message: 'New orders appear here the moment they are placed.',
                      icon: Icons.check_circle_outline_rounded,
                    )
                  : RefreshIndicator(
                      color: brand.primary,
                      onRefresh: () =>
                          ref.read(kitchenQueueProvider.notifier).refresh(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // A tablet in landscape fits two or three columns; a phone
                          // gets one.
                          final columns = constraints.maxWidth > 1100
                              ? 3
                              : (constraints.maxWidth > 720 ? 2 : 1);

                          return GridView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: orders.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 320,
                            ),
                            itemBuilder: (context, index) => KitchenTicketCard(
                              order: orders[index],
                              now: _now,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StageTabs extends ConsumerWidget {
  const _StageTabs({required this.counts, required this.selected});

  final KitchenCounts counts;
  final KitchenStage selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(bottom: BorderSide(color: brand.hairline)),
      ),
      child: Row(
        children: KitchenStage.values.map((stage) {
          final active = stage == selected;
          final count = counts.forStage(stage);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => ref.read(kitchenStageProvider.notifier).state = stage,
                borderRadius: BorderRadius.circular(brand.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? brand.primary : brand.surfaceMuted,
                    borderRadius: BorderRadius.circular(brand.radiusSm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : brand.ink,
                        ),
                      ),
                      Text(
                        stage.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white.withValues(alpha: 0.92)
                              : brand.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// One kitchen ticket.
class KitchenTicketCard extends ConsumerStatefulWidget {
  const KitchenTicketCard({required this.order, required this.now, super.key});

  final KitchenOrder order;
  final DateTime now;

  @override
  ConsumerState<KitchenTicketCard> createState() => _KitchenTicketCardState();
}

class _KitchenTicketCardState extends ConsumerState<KitchenTicketCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _primaryAction() {
    final controller = ref.read(kitchenQueueProvider.notifier);
    final order = widget.order;

    return switch (order.stage) {
      KitchenStage.newOrders => _accept(),
      KitchenStage.accepted => _run(() => controller.startPreparing(order.id)),
      KitchenStage.preparing => _run(() => controller.markReady(order.id)),
      KitchenStage.ready => Future.value(),
    };
  }

  /// Accepting offers a chance to revise the prep estimate, because the promise
  /// time the customer sees comes from it.
  Future<void> _accept() async {
    final minutes = await AppFeedback.sheet<int?>(
      context,
      builder: (_) => _PrepTimeSheet(
        suggested: widget.order.prepMinutesEstimate ?? 20,
      ),
    );

    if (minutes == null) return;
    await _run(
      () => ref
          .read(kitchenQueueProvider.notifier)
          .accept(orderId: widget.order.id, prepMinutes: minutes),
    );
  }

  Future<void> _reject() async {
    final result = await AppFeedback.sheet<_RejectionChoice?>(
      context,
      builder: (_) => const _RejectSheet(),
    );

    if (result == null) return;

    await _run(
      () => ref.read(kitchenQueueProvider.notifier).reject(
            orderId: widget.order.id,
            reason: result.reason,
            note: result.note,
          ),
    );
  }

  Future<void> _sharePickupCode() async {
    final order = widget.order;
    if (!order.canSharePickupCode) return;

    setState(() => _busy = true);
    try {
      final handoff = await ref
          .read(kitchenRepositoryProvider)
          .issuePickupHandoffCode(order.id);
      if (!mounted) return;
      await _showPickupCode(order, handoff);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPickupCode(KitchenOrder order, PickupHandoffCode handoff) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final brand = dialogContext.brand;
        final phone = handoff.riderPhone?.trim();
        final message =
            'Bites Box pickup code for ${order.orderNumber}: ${handoff.code}. '
            'Use it only to verify this order at pickup.';

        return AlertDialog(
          title: const Text('Pickup code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this code with ${handoff.riderName} so they can verify the parcel before leaving. It is valid only for the currently assigned rider.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: brand.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                ),
                child: SelectableText(
                  handoff.code,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: brand.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 9,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Valid for 6 hours. If dispatch assigns a replacement rider, issue a fresh code; the earlier code is invalidated.',
                style: TextStyle(fontSize: 12.5, color: brand.inkMuted, height: 1.35),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: handoff.code));
                if (dialogContext.mounted) {
                  AppFeedback.showSuccess(dialogContext, 'Pickup code copied');
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy code'),
            ),
            if (phone != null && phone.isNotEmpty)
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri(
                    scheme: 'sms',
                    path: phone,
                    queryParameters: {'body': message},
                  );
                  try {
                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (opened) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      return;
                    }
                  } catch (_) {
                    // Keep the handoff available when a device has no SMS app.
                  }

                  await Clipboard.setData(ClipboardData(text: message));
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  AppFeedback.showSuccess(
                    context,
                    'Message copied. Paste it into a message to the rider.',
                  );
                },
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Share with rider'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final order = widget.order;
    final elapsed = order.elapsedSecondsAt(widget.now);
    final urgent = order.needsAttention;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(
          color: urgent ? brand.error : brand.hairline,
          width: urgent ? 2 : 1.2,
        ),
      ),
      child: Column(
        children: [
          // ── Header: number, timer, flags ──
          Container
            (padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: urgent ? brand.error.withValues(alpha: 0.06) : brand.surfaceMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(brand.radiusMd)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: brand.ink,
                        ),
                      ),
                      Text(
                        '${order.unitCount} item${order.unitCount == 1 ? '' : 's'} · '
                        '${order.isPickup ? 'Pickup' : 'Delivery'}',
                        style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.elapsed(elapsed),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [],
                        color: urgent ? brand.error : brand.ink,
                      ),
                    ),
                    Text(
                      order.isDelayed ? 'overdue' : 'since placed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: urgent ? brand.error : brand.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Flags ──
          if (order.isScheduled ||
              order.isCod ||
              order.isFirstOrder ||
              order.rider?.isWaiting == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (order.isScheduled)
                    AppPill(
                      label: 'Scheduled ${Fmt.time(order.scheduledFor)}',
                      icon: Icons.event_rounded,
                      dense: true,
                      background: brand.secondary.withValues(alpha: 0.10),
                      foreground: brand.secondary,
                    ),
                  if (order.isCod)
                    AppPill(
                      label: 'Cash ${Fmt.moneySmart(order.grandTotal)}',
                      icon: Icons.payments_rounded,
                      dense: true,
                      background: brand.warning.withValues(alpha: 0.12),
                      foreground: brand.warning,
                    ),
                  if (order.isFirstOrder)
                    AppPill(
                      label: 'First order',
                      icon: Icons.star_rounded,
                      dense: true,
                      background: brand.accent.withValues(alpha: 0.16),
                      foreground: brand.warning,
                    ),
                  if (order.rider?.isWaiting == true)
                    AppPill(
                      label: 'Rider waiting',
                      icon: Icons.two_wheeler_rounded,
                      dense: true,
                      background: brand.error.withValues(alpha: 0.10),
                      foreground: brand.error,
                    ),
                ],
              ),
            ),
          // ── Items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              children: [
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: brand.ink,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  FoodTypeMark(foodType: item.foodType, size: 11),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.variantName == null
                                          ? item.productName
                                          : '${item.productName} (${item.variantName})',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        decoration: item.isCancelled
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: item.isCancelled
                                            ? brand.inkMuted
                                            : brand.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.modifierLine.isNotEmpty)
                                Text(
                                  item.modifierLine,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.3,
                                    color: brand.inkMuted,
                                  ),
                                ),
                              if (item.hasInstructions)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: brand.warning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    item.specialInstructions!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: brand.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if ((order.customerNote ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: brand.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(brand.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.priority_high_rounded, size: 15, color: brand.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.customerNote!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: brand.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ── Actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: order.stage == KitchenStage.ready
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: brand.success.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(brand.radiusMd),
                        ),
                        child: Text(
                          order.isPickup
                              ? 'Waiting at the counter'
                              : (order.rider?.isWaiting == true
                                  ? '${order.rider!.name} is waiting for handoff'
                                  : (order.rider == null
                                      ? 'Waiting for a delivery partner'
                                      : 'Rider assigned: ${order.rider!.name}')),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: brand.success,
                          ),
                        ),
                      ),
                      if (order.canSharePickupCode) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _sharePickupCode,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.share_rounded),
                            label: Text(
                              _busy ? 'Preparing code…' : 'Share pickup code with rider',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: brand.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      if (order.stage == KitchenStage.newOrders) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _reject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: brand.error,
                              side: BorderSide(
                                color: brand.error.withValues(alpha: 0.4),
                              ),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _busy ? null : _primaryAction,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: switch (order.stage) {
                              KitchenStage.newOrders => brand.success,
                              KitchenStage.accepted => brand.primary,
                              KitchenStage.preparing => brand.success,
                              KitchenStage.ready => brand.primary,
                            },
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(switch (order.stage) {
                                  KitchenStage.newOrders => 'Accept',
                                  KitchenStage.accepted => 'Start cooking',
                                  KitchenStage.preparing => 'Mark ready',
                                  KitchenStage.ready => 'Done',
                                }),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PrepTimeSheet extends StatefulWidget {
  const _PrepTimeSheet({required this.suggested});

  final int suggested;

  @override
  State<_PrepTimeSheet> createState() => _PrepTimeSheetState();
}

class _PrepTimeSheetState extends State<_PrepTimeSheet> {
  late int _minutes;

  static const _options = <int>[10, 15, 20, 25, 30, 40, 50, 60];

  @override
  void initState() {
    super.initState();
    _minutes = widget.suggested;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(
            title: 'How long will this take?',
            subtitle: 'This sets the time the customer is promised.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options
                  .map(
                    (value) => ChoiceChip(
                      label: Text('$value min'),
                      selected: _minutes == value,
                      onSelected: (_) => setState(() => _minutes = value),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_minutes),
              child: Text('Accept · ready in $_minutes min'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectionChoice {
  const _RejectionChoice({required this.reason, this.note});

  final String reason;
  final String? note;
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  String _reason = 'ITEM_UNAVAILABLE';
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(
              title: 'Reject this order',
              subtitle: 'The customer is refunded automatically and told why.',
            ),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value ?? _reason),
              child: Column(
                children: KitchenRepository.rejectionReasons.entries
                    .map(
                      (entry) => RadioListTile<String>(
                        value: entry.key,
                        dense: true,
                        title: Text(entry.value),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: TextField(
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Note for the record (optional)',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Keep it'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _RejectionChoice(reason: _reason, note: _note.text),
                      ),
                      style: FilledButton.styleFrom(backgroundColor: brand.error),
                      child: const Text('Reject order'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
