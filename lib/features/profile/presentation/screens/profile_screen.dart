import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/shimmer_widgets.dart';
import 'package:notes_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:notes_app/features/viewer/presentation/providers/viewer_provider.dart';

// TODO: set production URL once the site is deployed
const String kPrivacyPolicyUrl = 'https://YOUR-SITE-DOMAIN/privacy';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            AnimatedFadeIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'PROFILE',
                  style: GoogleFonts.archivoNarrow(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
              ),
            ),
            Container(height: 1, color: AppTheme.navy),
            // Content
            Expanded(
              child: profileState.isLoading && profileState.profile == null
                  ? _buildLoadingState()
                  : _buildContent(profileState, authState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SingleChildScrollView(
      child: Column(
        children: [
          GhostProfileHeader(),
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GhostProfileCard(),
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GhostProfileCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      ProfileState profileState, AuthState authState) {
    final profile = profileState.profile;
    final name =
        profile?['name'] as String? ?? authState.user?.email ?? 'User';
    final email = authState.user?.email ?? '';
    final rollNo = profile?['roll_no'] as String? ?? '';
    final initials =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile Header
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 100),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: AppTheme.navy,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.archivoNarrow(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    name.toUpperCase(),
                    style: GoogleFonts.archivoNarrow(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (rollNo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.navy),
                      ),
                      child: Text(
                        'ROLL NO: $rollNo',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.navy,
                          letterSpacing: 0.08,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(height: 1, color: AppTheme.navy),
          // Stats
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 300),
            child: _buildStatsSection(),
          ),
          Container(height: 1, color: AppTheme.navy),
          // Bookmarks
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 400),
            child: _buildBookmarksSection(ref),
          ),
          Container(height: 1, color: AppTheme.navy),
          // Actions
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 500),
            child: _buildActions(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.bookmark_outline,
              label: 'BOOKMARKS',
              value: '0',
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: AppTheme.navy,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.download_outlined,
              label: 'DOWNLOADED',
              value: '0',
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: AppTheme.navy,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.history,
              label: 'RECENT',
              value: '0',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.navy, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.archivoNarrow(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
            letterSpacing: 0.08,
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarksSection(WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksListProvider);

    return bookmarksAsync.when(
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline,
                    size: 20, color: AppTheme.navy),
                const SizedBox(width: 8),
                Text(
                  'BOOKMARKS',
                  style: GoogleFonts.archivoNarrow(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
                const Spacer(),
                Text(
                  'None yet',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: AppTheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark, size: 20, color: AppTheme.navy),
                  const SizedBox(width: 8),
                  Text(
                    'BOOKMARKS',
                    style: GoogleFonts.archivoNarrow(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${bookmarks.length}',
                    style: GoogleFonts.archivoNarrow(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...bookmarks.take(5).map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppTheme.navy,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${b['subject']} - ${b['chapter']}',
                            style: GoogleFonts.hankenGrotesk(
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
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildActionItem(
            icon: Icons.info_outline,
            label: 'ABOUT',
            onTap: () {},
          ),
          Container(height: 1, color: AppTheme.navy),
          _buildActionItem(
            icon: Icons.help_outline,
            label: 'HELP & SUPPORT',
            onTap: () {},
          ),
          Container(height: 1, color: AppTheme.navy),
          _buildActionItem(
            icon: Icons.privacy_tip_outlined,
            label: 'PRIVACY POLICY',
            onTap: () {
              launchUrl(Uri.parse(kPrivacyPolicyUrl),
                  mode: LaunchMode.externalApplication);
            },
          ),
          Container(height: 1, color: AppTheme.navy),
          _buildActionItem(
            icon: Icons.logout,
            label: 'SIGN OUT',
            color: AppTheme.error,
            onTap: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.navy, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.archivoNarrow(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? AppTheme.navy,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward,
              color: color ?? AppTheme.navy,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class GhostProfileCard extends StatelessWidget {
  const GhostProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceDim,
      highlightColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              color: AppTheme.outlineVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 120,
                    color: AppTheme.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 80,
                    color: AppTheme.outlineVariant,
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
