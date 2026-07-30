import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/content_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:notes_app/features/download/data/download_manager.dart';
import 'package:notes_app/features/download/presentation/providers/download_provider.dart';

class ChapterCard extends ConsumerWidget {
  final ContentModel content;
  final VoidCallback onTap;

  const ChapterCard({
    super.key,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionProvider);
    final hasAccess = content.isPreview || subState.subscription?.isActive == true;
    final downloadState = ref.watch(downloadProvider);
    final progress = downloadState[content.id];
    final isDownloading = progress != null && !progress.isComplete;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasAccess
                          ? AppTheme.navy.withAlpha(25)
                          : Colors.grey.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${content.chapter}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasAccess ? AppTheme.navy : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chapter ${content.chapter}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${content.pageCount} pages',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDownloading)
                    _DownloadProgressWidget(progress: progress)
                  else
                    _DownloadButton(content: content, hasAccess: hasAccess),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _AccessBadge(isPreview: content.isPreview, hasAccess: hasAccess),
                  const SizedBox(width: 8),
                  if (!hasAccess)
                    _AccessStatusBadge(
                      icon: Icons.lock_outline,
                      label: 'Subscribe to access',
                      color: AppTheme.textSecondary,
                    )
                  else if (content.isPreview)
                    _AccessStatusBadge(
                      icon: Icons.visibility_outlined,
                      label: 'Free preview',
                      color: AppTheme.success,
                    )
                  else
                    _AccessStatusBadge(
                      icon: Icons.check_circle_outline,
                      label: 'Included in plan',
                      color: AppTheme.success,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  final ContentModel content;
  final bool hasAccess;

  const _DownloadButton({required this.content, required this.hasAccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasAccess) return const SizedBox.shrink();

    final manager = ref.read(downloadManagerProvider);

    return FutureBuilder<bool>(
      future: manager.isChapterCached(content.id, content.pageCount),
      builder: (context, snapshot) {
        final isCached = snapshot.data ?? false;

        return IconButton(
          icon: Icon(
            isCached ? Icons.download_done : Icons.download_outlined,
            size: 20,
            color: isCached ? AppTheme.success : AppTheme.navy,
          ),
          tooltip: isCached ? 'Available offline' : 'Download for offline',
          onPressed: isCached
              ? () => _showDeleteDialog(context, ref)
              : () => _startDownload(ref),
        );
      },
    );
  }

  void _startDownload(WidgetRef ref) {
    ref.read(downloadProvider.notifier).download(content);
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove offline copy?'),
        content: Text(
          'Chapter ${content.chapter} will no longer be available offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(downloadManagerProvider).deleteChapter(content.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _DownloadProgressWidget extends StatelessWidget {
  final DownloadProgress progress;

  const _DownloadProgressWidget({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress.percentage,
            strokeWidth: 3,
            color: AppTheme.navy,
            backgroundColor: AppTheme.navy.withAlpha(30),
          ),
          Center(
            child: Text(
              '${(progress.percentage * 100).toInt()}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessBadge extends StatelessWidget {
  final bool isPreview;
  final bool hasAccess;

  const _AccessBadge({required this.isPreview, required this.hasAccess});

  @override
  Widget build(BuildContext context) {
    if (isPreview) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.success.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.success.withAlpha(80)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, size: 12, color: AppTheme.success),
            SizedBox(width: 4),
            Text(
              'FREE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.success,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.navy.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.navy.withAlpha(60)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 12, color: AppTheme.navy),
          SizedBox(width: 4),
          Text(
            'PAID',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AccessStatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    );
  }
}
