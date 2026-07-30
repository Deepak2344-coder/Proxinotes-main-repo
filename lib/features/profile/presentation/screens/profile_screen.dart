import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/loading_widget.dart';
import 'package:notes_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:notes_app/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:notes_app/features/viewer/presentation/providers/viewer_provider.dart';
import 'package:notes_app/features/download/presentation/providers/download_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final subState = ref.watch(subscriptionProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileState.isLoading
          ? const LoadingWidget()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileHeader(profileState, authState),
                const SizedBox(height: 24),
                _buildSubscriptionCard(subState),
                const SizedBox(height: 16),
                _buildStorageSection(ref),
                const SizedBox(height: 16),
                _buildBookmarksSection(ref),
                const SizedBox(height: 24),
                _buildActions(context, ref),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(ProfileState profileState, AuthState authState) {
    final profile = profileState.profile;
    final name = profile?['name'] as String? ?? authState.user?.email ?? 'User';
    final email = authState.user?.email ?? '';
    final rollNo = profile?['roll_no'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.amber,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  if (rollNo.isNotEmpty)
                    Text(
                      'Roll No: $rollNo',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
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

  Widget _buildSubscriptionCard(SubscriptionState subState) {
    final sub = subState.subscription;
    final isActive = sub?.isActive ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.success.withAlpha(25)
                    : AppTheme.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? Icons.verified : Icons.subscriptions_outlined,
                color: isActive ? AppTheme.success : AppTheme.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? 'Subscription Active' : 'No Active Subscription',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (sub?.currentPeriodEnd != null)
                    Text(
                      'Valid until ${_formatDate(sub!.currentPeriodEnd!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
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

  Widget _buildStorageSection(WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider);

    return FutureBuilder<List<int>>(
      future: Future.wait([
        manager.getTotalCacheSize(),
        manager.getTotalCachedChapters(),
      ]),
      builder: (context, snapshot) {
        final totalSize = snapshot.data?[0] ?? 0;
        final chapterCount = snapshot.data?[1] ?? 0;
        final sizeStr = _formatSize(totalSize);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storage, size: 20, color: AppTheme.navy),
                    SizedBox(width: 8),
                    Text(
                      'Offline Storage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StorageChip(
                      icon: Icons.folder_outlined,
                      label: '$chapterCount chapters',
                    ),
                    const SizedBox(width: 8),
                    _StorageChip(
                      icon: Icons.speed,
                      label: sizeStr,
                    ),
                  ],
                ),
                if (chapterCount > 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showClearDialog(context, ref),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear All Downloads'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all downloads?'),
        content: const Text(
          'All cached chapters will be removed. You can re-download them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(downloadManagerProvider).clearAllDownloads();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildBookmarksSection(WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksListProvider);

    return bookmarksAsync.when(
      data: (bookmarks) {
        if (bookmarks.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bookmark, size: 20, color: AppTheme.navy),
                    SizedBox(width: 8),
                    Text(
                      'Bookmarks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...bookmarks.take(5).map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${b['subject']} - ${b['chapter']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.logout, color: AppTheme.error),
          title: const Text(
            'Sign Out',
            style: TextStyle(color: AppTheme.error),
          ),
          onTap: () {
            ref.read(authProvider.notifier).signOut();
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StorageChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StorageChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.navy.withAlpha(10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}
