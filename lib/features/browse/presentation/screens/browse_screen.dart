import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/course_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/error_display.dart';
import 'package:notes_app/core/widgets/loading_widget.dart';
import 'package:notes_app/core/widgets/empty_display.dart';
import 'package:notes_app/features/browse/presentation/providers/course_provider.dart';
import 'package:notes_app/features/browse/presentation/screens/course_detail_screen.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(courseRefreshProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Courses'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(courseRefreshProvider.notifier).refresh();
        },
        child: coursesAsync.when(
          data: (courses) {
            if (courses.isEmpty) {
              return const EmptyDisplay(
                message: 'No courses available yet',
                icon: Icons.school_outlined,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              itemBuilder: (_, i) => _CourseCard(
                course: courses[i],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseDetailScreen(course: courses[i]),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const LoadingWidget(message: 'Loading courses...'),
          error: (e, _) => ErrorDisplay(
            message: 'No internet. Showing cached data.',
            onRetry: () => ref.read(courseRefreshProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.navy.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: AppTheme.navy, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (course.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (course.price > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.navy.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₹${course.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
