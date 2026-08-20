import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../providers/customer_providers.dart';

/// Rate an order.
///
/// Food and delivery are rated separately because they are different teams; a slow
/// rider should not drag down the kitchen's score, and the admin dashboard reports
/// on each independently.
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({required this.orderId, this.isDelivery = true, super.key});

  final String orderId;
  final bool isDelivery;

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    bool isDelivery = true,
  }) {
    return AppFeedback.sheet<void>(
      context,
      builder: (_) => ReviewSheet(orderId: orderId, isDelivery: isDelivery),
    );
  }

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  int _food = 0;
  int _delivery = 0;
  final _comment = TextEditingController();
  final Set<String> _tags = {};
  bool _busy = false;

  static const _positiveTags = <String>[
    'Tasty',
    'Well packed',
    'Hot and fresh',
    'Quick delivery',
    'Good portion',
    'Value for money',
  ];

  static const _negativeTags = <String>[
    'Arrived cold',
    'Too late',
    'Spillage',
    'Small portion',
    'Too salty',
    'Not as described',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// The overall score is the average of what the customer actually rated.
  int get _overall {
    final scores = [_food, if (widget.isDelivery && _delivery > 0) _delivery]
        .where((score) => score > 0)
        .toList();
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  List<String> get _tagOptions => _food >= 4 ? _positiveTags : _negativeTags;

  Future<void> _submit() async {
    if (_food == 0) {
      AppFeedback.showInfo(context, 'Please rate the food first.');
      return;
    }

    setState(() => _busy = true);

    try {
      await ref.read(orderRepositoryProvider).submitReview(
            orderId: widget.orderId,
            foodRating: _food,
            overallRating: _overall,
            deliveryRating: widget.isDelivery && _delivery > 0 ? _delivery : null,
            comment: _comment.text,
            tags: _tags.toList(),
          );

      if (!mounted) return;
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(myOrdersProvider);

      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Thank you. Your feedback helps us improve.');
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
            const SheetHeader(
              title: 'How was your meal?',
              subtitle: 'Your rating goes straight to our kitchen team.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StarRow(
                    label: 'The food',
                    value: _food,
                    onChanged: (value) => setState(() {
                      _food = value;
                      // Tag options flip between praise and problems.
                      _tags.clear();
                    }),
                  ),
                  if (widget.isDelivery) ...[
                    const SizedBox(height: 16),
                    _StarRow(
                      label: 'The delivery',
                      value: _delivery,
                      onChanged: (value) => setState(() => _delivery = value),
                    ),
                  ],
                  if (_food > 0) ...[
                    const SizedBox(height: 20),
                    Text(
                      _food >= 4 ? 'What went well?' : 'What went wrong?',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: brand.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tagOptions
                          .map(
                            (tag) => FilterChip(
                              label: Text(tag),
                              selected: _tags.contains(tag),
                              showCheckmark: false,
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _tags.add(tag);
                                } else {
                                  _tags.remove(tag);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    controller: _comment,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Tell us more (optional)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || _food == 0 ? null : _submit,
                    child: Text(_busy ? 'Sending…' : 'Submit rating'),
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

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = <int, String>{
    1: 'Poor',
    2: 'Not great',
    3: 'Fine',
    4: 'Good',
    5: 'Excellent',
  };

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: brand.ink,
              ),
            ),
            if (value > 0) ...[
              const SizedBox(width: 8),
              Text(
                _labels[value] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value >= 4 ? brand.success : brand.warning,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (index) {
            final star = index + 1;
            final filled = star <= value;

            return Semantics(
              button: true,
              label: '$star star${star == 1 ? '' : 's'}',
              child: IconButton(
                onPressed: () => onChanged(star),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 32,
                  color: filled ? brand.accent : brand.inkMuted.withValues(alpha: 0.45),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
