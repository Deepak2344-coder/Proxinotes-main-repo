import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/course_model.dart';
import 'package:notes_app/core/models/subject_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/error_display.dart';
import 'package:notes_app/core/widgets/loading_widget.dart';
import 'package:notes_app/core/widgets/empty_display.dart';
import 'package:notes_app/features/browse/presentation/providers/course_provider.dart';
import 'package:notes_app/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:notes_app/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:notes_app/features/browse/presentation/screens/subject_detail_screen.dart';

class CourseDetailScreen extends ConsumerWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool hasAccess = false;
    try {
      final subState = ref.watch(subscriptionProvider);
      hasAccess = subState.subscription?.isActive == true;
    } catch (_) {
      hasAccess = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(course.name),
      ),
      body: Column(
        children: [
          if (!hasAccess) _PurchaseBanner(course: course),
          Expanded(
            child: hasAccess
                ? _SubjectList(course: course)
                : _LockedView(course: course),
          ),
        ],
      ),
    );
  }
}

class _PurchaseBanner extends StatelessWidget {
  final CourseModel course;

  const _PurchaseBanner({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navy, AppTheme.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Access this course',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Subscribe to access all subjects and materials',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amber,
              foregroundColor: AppTheme.navy,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              course.price > 0 ? '₹${course.price.toStringAsFixed(0)}' : 'Subscribe',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectList extends ConsumerWidget {
  final CourseModel course;

  const _SubjectList({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<SubjectModel>> subjectsAsync;
    try {
      subjectsAsync = ref.watch(subjectsForCourseProvider(course.id));
    } catch (_) {
      return const ErrorDisplay(message: 'Failed to load subjects');
    }

    return subjectsAsync.when(
      data: (subjects) {
        if (subjects.isEmpty) {
          return const EmptyDisplay(
            message: 'No subjects in this course yet',
            icon: Icons.folder_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: subjects.length,
          itemBuilder: (_, i) => _SubjectCard(
            subject: subjects[i],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubjectDetailScreen(
                    subject: subjects[i],
                    courseName: course.name,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingWidget(message: 'Loading subjects...'),
      error: (e, _) => ErrorDisplay(message: e.toString()),
    );
  }
}

class _LockedView extends ConsumerWidget {
  final CourseModel course;

  const _LockedView({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<SubjectModel>> subjectsAsync;
    try {
      subjectsAsync = ref.watch(subjectsForCourseProvider(course.id));
    } catch (_) {
      return const ErrorDisplay(message: 'Failed to load subjects');
    }

    return subjectsAsync.when(
      data: (subjects) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (course.description.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  course.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (course.specs.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.navy.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.navy.withAlpha(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What\'s included',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.specs,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ...subjects.map((s) => Opacity(
              opacity: 0.5,
              child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined, color: AppTheme.textSecondary),
                  title: Text(
                    s.name,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
                ),
              ),
            )),
          ],
        );
      },
      loading: () => const LoadingWidget(message: 'Loading...'),
      error: (e, _) => ErrorDisplay(message: e.toString()),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onTap;

  const _SubjectCard({required this.subject, required this.onTap});

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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_outlined, color: AppTheme.amber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  subject.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
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
