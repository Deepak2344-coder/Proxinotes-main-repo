import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/content_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/error_display.dart';
import 'package:notes_app/core/widgets/loading_widget.dart';
import 'package:notes_app/core/widgets/empty_display.dart';
import 'package:notes_app/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:notes_app/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:notes_app/features/viewer/presentation/screens/page_viewer_screen.dart';
import 'package:notes_app/features/browse/presentation/providers/content_provider.dart';
import 'package:notes_app/features/browse/presentation/widgets/chapter_card.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChapter(ContentModel content) {
    final subState = ref.read(subscriptionProvider);
    final hasAccess = content.isPreview || subState.subscription?.isActive == true;

    if (!hasAccess) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubscriptionScreen(
            onSubscribed: () {
              Navigator.of(context).pop();
              _openChapter(content);
            },
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageViewerScreen(content: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final contentAsync = ref.watch(contentRefreshProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search subjects, chapters...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  ref.read(searchQueryProvider.notifier).state = v;
                },
              )
            : const Text('Browse Notes'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
        ],
      ),
      body: _isSearching
          ? _buildSearchResults(searchResults)
          : _buildBrowse(contentAsync),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<ContentModel>> results) {
    return results.when(
      data: (items) {
        if (items.isEmpty) {
          final query = ref.watch(searchQueryProvider);
          if (query.isEmpty) {
            return const EmptyDisplay(
              message: 'Type to search subjects and chapters',
              icon: Icons.search,
            );
          }
          return EmptyDisplay(
            message: 'No results for "$query"',
            icon: Icons.search_off,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) => ChapterCard(
            content: items[i],
            onTap: () => _openChapter(items[i]),
          ),
        );
      },
      loading: () => const LoadingWidget(message: 'Searching...'),
      error: (e, _) => ErrorDisplay(message: e.toString()),
    );
  }

  Widget _buildBrowse(AsyncValue<List<ContentModel>> contentAsync) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(contentRefreshProvider.notifier).refresh();
      },
      child: contentAsync.when(
        data: (allContent) {
          final grouped = <String, List<ContentModel>>{};
          for (final c in allContent) {
            grouped.putIfAbsent(c.subject, () => []).add(c);
          }

          if (grouped.isEmpty) {
            return const EmptyDisplay(
              message: 'No notes available yet',
              icon: Icons.menu_book_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...grouped.entries.map((entry) => _buildSubjectSection(
                    entry.key,
                    entry.value,
                  )),
            ],
          );
        },
        loading: () => const LoadingWidget(message: 'Loading notes...'),
        error: (e, _) => ErrorDisplay(
          message: 'No internet. Showing cached data.',
          onRetry: () {
            ref.read(contentRefreshProvider.notifier).refresh();
          },
        ),
      ),
    );
  }

  Widget _buildSubjectSection(String subject, List<ContentModel> chapters) {
    final freeCount = chapters.where((c) => c.isPreview).length;
    final paidCount = chapters.where((c) => c.isPaid).length;
    final totalPages = chapters.fold<int>(0, (sum, c) => sum + c.pageCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_outlined, color: AppTheme.navy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _SummaryChip(
                      icon: Icons.book_outlined,
                      label: '${chapters.length} ch',
                    ),
                    _SummaryChip(
                      icon: Icons.description_outlined,
                      label: '$totalPages pages',
                    ),
                    if (freeCount > 0)
                      _SummaryChip(
                        icon: Icons.open_in_new,
                        label: '$freeCount free',
                        color: AppTheme.success,
                      ),
                    if (paidCount > 0)
                      _SummaryChip(
                        icon: Icons.workspace_premium,
                        label: '$paidCount paid',
                        color: AppTheme.navy,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...chapters.map((c) => ChapterCard(
              content: c,
              onTap: () => _openChapter(c),
            )),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
