import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/launcher.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/account_models.dart';
import '../data/order_models.dart';
import '../providers/customer_providers.dart';

/// Support: the customer's tickets, one conversation, and raising a new one.
///
/// Refunds and goodwill credit are never offered here. A ticket describes the
/// problem; the back office decides the remedy, which keeps money decisions in one
/// audited place.
class SupportListScreen extends ConsumerWidget {
  const SupportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final tickets = ref.watch(supportTicketsProvider);
    final config = ref.watch(appConfigProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Help and support')),
      body: Column(
        children: [
          _ContactStrip(phone: config?.supportPhone, whatsapp: config?.whatsappPhone),
          Expanded(
            child: AsyncValueView<List<SupportTicket>>(
              value: tickets,
              onRetry: () => ref.invalidate(supportTicketsProvider),
              data: (list) {
                if (list.isEmpty) {
                  return const AppEmptyState(
                    title: 'No support requests',
                    message: 'If something goes wrong with an order, raise a request and we will sort it out.',
                    icon: Icons.support_agent_rounded,
                  );
                }

                return RefreshIndicator(
                  color: brand.primary,
                  onRefresh: () async {
                    ref.invalidate(supportTicketsProvider);
                    await ref.read(supportTicketsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _TicketCard(ticket: list[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newTicket),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
    );
  }
}

class _ContactStrip extends StatelessWidget {
  const _ContactStrip({this.phone, this.whatsapp});

  final String? phone;
  final String? whatsapp;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (phone == null && whatsapp == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Need to speak to someone right away?',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: brand.inkMuted),
            ),
          ),
          if (phone != null)
            IconButton.filledTonal(
              onPressed: () => Launcher.dial(phone),
              icon: const Icon(Icons.call_rounded, size: 20),
              tooltip: 'Call us',
            ),
          if (whatsapp != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => Launcher.whatsapp(whatsapp),
              icon: const Icon(Icons.chat_rounded, size: 20),
              tooltip: 'Message us on WhatsApp',
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final colour = ticket.isOpen ? brand.secondary : brand.success;

    return InkWell(
      onTap: () => context.push(Routes.ticket(ticket.id)),
      borderRadius: BorderRadius.circular(brand.radiusMd),
      child: Container(
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
                AppPill(
                  label: ticket.statusLabel,
                  dense: true,
                  background: colour.withValues(alpha: 0.10),
                  foreground: colour,
                ),
                const Spacer(),
                Text(
                  Fmt.smartDateTime(ticket.lastMessageAt ?? ticket.createdAt),
                  style: TextStyle(fontSize: 12, color: brand.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ticket.subject,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: brand.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${ticket.ticketNumber} · ${ticket.categoryLabel}',
              style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── One conversation ───────────────────────────────────────────────────────
class SupportThreadScreen extends ConsumerStatefulWidget {
  const SupportThreadScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  ConsumerState<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty) return;

    setState(() => _sending = true);

    try {
      await ref
          .read(accountRepositoryProvider)
          .postMessage(ticketId: widget.ticketId, body: body);

      _message.clear();
      ref.invalidate(supportThreadProvider(widget.ticketId));
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final thread = ref.watch(supportThreadProvider(widget.ticketId));

    return Scaffold(
      appBar: AppBar(
        title: Text(thread.valueOrNull?.ticket.ticketNumber ?? 'Support'),
      ),
      body: AsyncValueView<SupportThread>(
        value: thread,
        onRetry: () => ref.invalidate(supportThreadProvider(widget.ticketId)),
        data: (data) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TicketSummary(ticket: data.ticket, order: data.order),
                  const SizedBox(height: 18),
                  ...data.messages.map((message) => _MessageBubble(message: message)),
                  if (data.messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Text(
                        'Our team will reply here shortly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: brand.inkMuted),
                      ),
                    ),
                ],
              ),
            ),
            if (data.ticket.isOpen)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: brand.surface,
                  border: Border(top: BorderSide(color: brand.hairline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Type a message…',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send_rounded, size: 20),
                        tooltip: 'Send',
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: brand.surfaceMuted,
                child: SafeArea(
                  top: false,
                  child: Text(
                    'This request is ${data.ticket.statusLabel.toLowerCase()}. '
                    'Raise a new one if you still need help.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: brand.inkMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketSummary extends StatelessWidget {
  const _TicketSummary({required this.ticket, this.order});

  final SupportTicket ticket;
  final OrderDetail? order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surfaceMuted,
        borderRadius: BorderRadius.circular(brand.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.subject,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ticket.categoryLabel} · raised ${Fmt.smartDateTime(ticket.createdAt)}',
            style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
          ),
          if (order != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => context.push(Routes.order(order!.id)),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 15, color: brand.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${order!.orderNumber} · ${Fmt.moneySmart(order!.totals.grandTotal)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: brand.primary,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 17, color: brand.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final mine = message.isFromCustomer;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? brand.primary : brand.surface,
          borderRadius: BorderRadius.circular(brand.radiusMd).subtract(
            BorderRadius.only(
              bottomRight: mine ? const Radius.circular(10) : Radius.zero,
              bottomLeft: mine ? Radius.zero : const Radius.circular(10),
            ),
          ),
          border: mine ? null : Border.all(color: brand.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && message.authorName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.authorName!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: brand.primary,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: mine ? Colors.white : brand.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              Fmt.smartDateTime(message.createdAt),
              style: TextStyle(
                fontSize: 10.5,
                color: mine ? Colors.white.withValues(alpha: 0.75) : brand.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Raising a request ──────────────────────────────────────────────────────
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  String _category = 'OTHER';
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _orderId;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _subject.text.trim().length >= 4 && _description.text.trim().length >= 10;

  Future<void> _submit() async {
    setState(() => _busy = true);

    try {
      final ticketId = await ref.read(accountRepositoryProvider).createTicket(
            category: _category,
            subject: _subject.text,
            description: _description.text,
            orderId: _orderId,
          );

      if (!mounted) return;
      ref.invalidate(supportTicketsProvider);
      AppFeedback.showSuccess(context, 'Request raised. We will reply shortly.');

      if (ticketId.isNotEmpty) {
        context.pushReplacement(Routes.ticket(ticketId));
      } else {
        context.pop();
      }
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
    final orders = ref.watch(myOrdersProvider('ALL')).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'What is this about?',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: SupportTicket.categoryLabels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value ?? 'OTHER'),
          ),
          const SizedBox(height: 14),
          if (orders != null && orders.orders.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _orderId,
              decoration: const InputDecoration(
                labelText: 'Related order (optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not about a specific order'),
                ),
                ...orders.orders.take(15).map(
                      (order) => DropdownMenuItem<String?>(
                        value: order.id,
                        child: Text(
                          '${order.orderNumber} · ${Fmt.moneySmart(order.grandTotal)}',
                        ),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _orderId = value),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _subject,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Subject',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tell us what happened',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || !_isValid ? null : _submit,
            child: Text(_busy ? 'Sending…' : 'Raise request'),
          ),
        ],
      ),
    );
  }
}

/// Quick "something is wrong with this order" sheet, opened from tracking.
class OrderHelpSheet extends ConsumerStatefulWidget {
  const OrderHelpSheet({required this.order, super.key});

  final OrderDetail order;

  static Future<void> show(BuildContext context, {required OrderDetail order}) {
    return AppFeedback.sheet<void>(
      context,
      builder: (_) => OrderHelpSheet(order: order),
    );
  }

  @override
  ConsumerState<OrderHelpSheet> createState() => _OrderHelpSheetState();
}

class _OrderHelpSheetState extends ConsumerState<OrderHelpSheet> {
  String? _category;
  final _description = TextEditingController();
  final Set<String> _itemIds = {};
  bool _busy = false;

  /// The problems worth a dedicated shortcut. Everything else goes through the
  /// full form.
  static const _quickCategories = <String, String>{
    'MISSING_ITEM': 'Something was missing',
    'WRONG_ITEM': 'I got the wrong item',
    'FOOD_QUALITY': 'Problem with the food',
    'ORDER_DELAYED': 'My order is very late',
    'DELIVERY_ISSUE': 'Problem with the delivery',
    'OTHER': 'Something else',
  };

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _needsItems =>
      _category == 'MISSING_ITEM' || _category == 'WRONG_ITEM' || _category == 'FOOD_QUALITY';

  Future<void> _submit() async {
    setState(() => _busy = true);

    try {
      final ticketId = await ref.read(orderRepositoryProvider).requestHelp(
            orderId: widget.order.id,
            category: _category!,
            description: _description.text,
            itemIds: _itemIds.toList(),
          );

      if (!mounted) return;
      ref.invalidate(supportTicketsProvider);
      Navigator.of(context).pop();

      AppFeedback.showSuccess(context, 'Our team is looking into it.');
      if (ticketId.isNotEmpty) context.push(Routes.ticket(ticketId));
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: 'What went wrong?',
              subtitle: 'Order ${widget.order.orderNumber}',
            ),
            RadioGroup<String>(
              groupValue: _category,
              onChanged: (value) => setState(() {
                _category = value;
                // Item selection only makes sense for the category it was made in.
                _itemIds.clear();
              }),
              child: Column(
                children: _quickCategories.entries
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
            if (_needsItems) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Text(
                  'Which items?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
              ),
              ...widget.order.items.map(
                (item) => CheckboxListTile(
                  value: _itemIds.contains(item.id),
                  dense: true,
                  title: Text('${item.quantity} × ${item.productName}'),
                  subtitle: item.configurationLabel.isEmpty
                      ? null
                      : Text(item.configurationLabel),
                  onChanged: (selected) => setState(() {
                    if (selected ?? false) {
                      _itemIds.add(item.id);
                    } else {
                      _itemIds.remove(item.id);
                    }
                  }),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _description,
                maxLines: 3,
                maxLength: 600,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe the problem so we can put it right',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Our team will review this and decide on any refund or credit.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: brand.inkMuted),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                onPressed: _busy ||
                        _category == null ||
                        _description.text.trim().length < 10
                    ? null
                    : _submit,
                child: Text(_busy ? 'Sending…' : 'Send to support'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
