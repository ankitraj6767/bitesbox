import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/customer_providers.dart';
import '../widgets/cart_bar.dart';
import '../widgets/product_card.dart';

/// Menu search.
///
/// Matching is typo-tolerant and happens in Postgres (full-text rank blended with
/// trigram similarity), so "biriyani" still finds biryani. Keystrokes are
/// debounced so a fast typist causes one query, not ten.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  static const _debounceDelay = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = value;
    });
    setState(() {});
  }

  void _submitTerm(String term) {
    _debounce?.cancel();
    _controller.text = term;
    _focus.unfocus();
    ref.read(searchQueryProvider.notifier).state = term;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final query = _controller.text.trim();
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search for biryani, litti, thali…',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Clear',
                  ),
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: _onChanged,
          onSubmitted: _submitTerm,
        ),
      ),
      body: query.length < 2
          ? _Suggestions(onPick: _submitTerm)
          : AsyncValueView<SearchResults?>(
              value: results,
              onRetry: () => ref.invalidate(searchResultsProvider),
              loading: const _SearchSkeleton(),
              data: (data) {
                if (data == null) return _Suggestions(onPick: _submitTerm);

                if (data.products.isEmpty) {
                  return AppEmptyState(
                    title: 'No dishes match "${data.query}"',
                    message:
                        'Check the spelling, or browse the menu to see everything we cook.',
                    icon: Icons.search_off_rounded,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: data.products.length + 1,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: brand.hairline,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(
                          '${data.count} result${data.count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: brand.inkMuted,
                          ),
                        ),
                      );
                    }

                    return ProductListCard(product: data.products[index - 1]);
                  },
                );
              },
            ),
      bottomNavigationBar: const CartBar(),
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final suggestions = ref.watch(searchSuggestionsProvider);

    return AsyncValueView<SearchSuggestions>(
      value: suggestions,
      onRetry: () => ref.invalidate(searchSuggestionsProvider),
      data: (data) => ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (data.recent.isNotEmpty)
            _TermGroup(
              title: 'Your recent searches',
              terms: data.recent,
              icon: Icons.history_rounded,
              onPick: onPick,
            ),
          if (data.trending.isNotEmpty)
            _TermGroup(
              title: 'Trending this week',
              terms: data.trending,
              icon: Icons.trending_up_rounded,
              onPick: onPick,
            ),
          if (data.popularProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: Text(
                'Most ordered',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: brand.ink,
                ),
              ),
            ),
            ...data.popularProducts.map(
              (product) => ProductListCard(product: product),
            ),
          ],
          if (data.recent.isEmpty &&
              data.trending.isEmpty &&
              data.popularProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: AppEmptyState(
                title: 'What are you craving?',
                message: 'Start typing to search our whole menu.',
                icon: Icons.search_rounded,
              ),
            ),
        ],
      ),
    );
  }
}

class _TermGroup extends StatelessWidget {
  const _TermGroup({
    required this.title,
    required this.terms,
    required this.icon,
    required this.onPick,
  });

  final String title;
  final List<String> terms;
  final IconData icon;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: brand.inkMuted),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: brand.ink,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: terms
                .map(
                  (term) => ActionChip(
                    label: Text(term),
                    onPressed: () => onPick(term),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, __) => const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 16),
                SizedBox(height: 8),
                SkeletonBox(width: 80, height: 14),
              ],
            ),
          ),
          SizedBox(width: 14),
          SkeletonBox(width: 112, height: 96, radius: 14),
        ],
      ),
    );
  }
}
