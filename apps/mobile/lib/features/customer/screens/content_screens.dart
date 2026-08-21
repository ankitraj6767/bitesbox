import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/content_models.dart';
import '../providers/customer_providers.dart';

class PoliciesScreen extends ConsumerWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(publishedDocumentsProvider);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: const Text('Policies and terms')),
      body: AsyncValueView<List<CmsDocument>>(
        value: documents,
        onRetry: () => ref.invalidate(publishedDocumentsProvider),
        data: (items) => RefreshIndicator(
          color: brand.primary,
          onRefresh: () async {
            ref.invalidate(publishedDocumentsProvider);
            await ref.read(publishedDocumentsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    AppEmptyState(
                      title: 'No policies published',
                      message: 'Please check back shortly.',
                      icon: Icons.description_outlined,
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _PolicyCard(document: items[index]),
                ),
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.document});

  final CmsDocument document;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(Icons.description_outlined, color: brand.inkMuted),
        title: Text(
          document.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: brand.ink,
          ),
        ),
        subtitle: Text(
          '${document.kindLabel} · v${document.version}${document.effectiveFrom == null ? '' : ' · effective ${Fmt.day(document.effectiveFrom!)}'}',
          style: TextStyle(fontSize: 12, color: brand.inkMuted),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              document.body,
              style: TextStyle(fontSize: 13.5, height: 1.55, color: brand.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class FaqsScreen extends ConsumerWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(publishedFaqsProvider);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: const Text('Frequently asked questions')),
      body: AsyncValueView<List<CmsFaq>>(
        value: faqs,
        onRetry: () => ref.invalidate(publishedFaqsProvider),
        data: (items) => RefreshIndicator(
          color: brand.primary,
          onRefresh: () async {
            ref.invalidate(publishedFaqsProvider);
            await ref.read(publishedFaqsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    AppEmptyState(
                      title: 'No FAQs published',
                      message: 'Please check back shortly.',
                      icon: Icons.help_outline_rounded,
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  children: _grouped(items).entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _FaqGroup(
                            category: entry.key,
                            items: entry.value,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ),
    );
  }

  static Map<String, List<CmsFaq>> _grouped(List<CmsFaq> items) {
    final groups = <String, List<CmsFaq>>{};
    for (final item in items) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }
    return groups;
  }
}

class _FaqGroup extends StatelessWidget {
  const _FaqGroup({required this.category, required this.items});

  final String category;
  final List<CmsFaq> items;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            items.first.categoryLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: brand.inkMuted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: brand.surface,
            borderRadius: BorderRadius.circular(brand.radiusMd),
            border: Border.all(color: brand.hairline),
          ),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) Divider(height: 1, color: brand.hairline),
                ExpansionTile(
                  title: Text(
                    items[index].question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: brand.ink,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        items[index].answer,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: brand.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
