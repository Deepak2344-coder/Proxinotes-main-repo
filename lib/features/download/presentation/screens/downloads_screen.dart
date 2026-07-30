import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/features/download/data/download_manager.dart';
import 'package:notes_app/features/download/presentation/providers/download_provider.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  List<CachedChapterInfo> _cachedChapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final manager = ref.read(downloadManagerProvider);
      final chapters = await manager.getCachedChapterDetails();
      if (mounted) {
        setState(() {
          _cachedChapters = chapters;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cachedChapters.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download_outlined,
                size: 64, color: AppTheme.textSecondary.withAlpha(60)),
            const SizedBox(height: 16),
            const Text('No downloads yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'Download chapters from Browse\nto access them offline',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14,
                  color: AppTheme.textSecondary.withAlpha(150)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final totalSize = _cachedChapters.fold<int>(0, (s, c) => s + c.totalSize);

    return Column(
      children: [
        _buildStorageHeader(totalSize),
        const SizedBox(height: 8),
        Expanded(child: _buildChapterList()),
      ],
    );
  }

  Widget _buildStorageHeader(int totalSize) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.navy.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, size: 20, color: AppTheme.navy),
          const SizedBox(width: 8),
          Text('${_cachedChapters.length} chapters',
              style: const TextStyle(fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const Spacer(),
          Text(_formatSize(totalSize),
              style: TextStyle(fontSize: 13,
                  color: AppTheme.textSecondary.withAlpha(180))),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _showClearDialog,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.delete_outline, size: 20,
                  color: AppTheme.error.withAlpha(180)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    return RefreshIndicator(
      onRefresh: _loadChapters,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _cachedChapters.length,
        itemBuilder: (context, index) {
          final chapter = _cachedChapters[index];
          final parts = chapter.contentId.split('_');
          final subject =
              parts.length > 1 ? parts.sublist(1).join('_') : chapter.contentId;
          final display = subject.replaceAll('_', ' ');

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openChapter(chapter.contentId),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.navy.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.navy.withAlpha(15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.navy.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_outlined,
                          size: 22, color: AppTheme.navy),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(display,
                              style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(
                            '${chapter.pageCount} pages · ${chapter.formattedSize}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppTheme.error.withAlpha(150),
                      onPressed: () => _showDeleteDialog(chapter.contentId, display),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openChapter(String contentId) {
    // TODO: Navigate to viewer — needs content model from cache metadata
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $contentId...')),
    );
  }

  void _showDeleteDialog(String contentId, String displayName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete download?'),
        content: Text(
            'Remove "$displayName" from your device? You can re-download it later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref
                  .read(downloadManagerProvider)
                  .deleteChapter(contentId);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadChapters();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all downloads?'),
        content: const Text(
            'All cached chapters will be removed. You can re-download them later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref
                  .read(downloadManagerProvider)
                  .clearAllDownloads();
              if (ctx.mounted) Navigator.pop(ctx);
              _loadChapters();
            },
            child: const Text('Clear',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
