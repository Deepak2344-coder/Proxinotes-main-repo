import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/course_model.dart';
import 'package:notes_app/core/models/subject_model.dart';
import 'package:notes_app/core/models/unit_model.dart';
import 'package:notes_app/features/browse/data/course_repository.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(ref.read(supabaseClientProvider));
});

final activeCoursesProvider = FutureProvider<List<CourseModel>>((ref) async {
  return ref.read(courseRepositoryProvider).getActiveCourses();
});

final subjectsForCourseProvider =
    FutureProvider.family<List<SubjectModel>, String>((ref, courseId) async {
  return ref.read(courseRepositoryProvider).getSubjectsForCourse(courseId);
});

final unitsForSubjectProvider =
    FutureProvider.family<List<UnitModel>, String>((ref, subjectId) async {
  return ref.read(courseRepositoryProvider).getUnitsForSubject(subjectId);
});

class CourseRefreshNotifier extends StateNotifier<AsyncValue<List<CourseModel>>> {
  final CourseRepository _repo;

  CourseRefreshNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repo.getActiveCourses();
      state = AsyncValue.data(items);
    } catch (e) {
      if (state.value == null) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> refresh() async {
    try {
      final items = await _repo.getActiveCourses();
      state = AsyncValue.data(items);
    } catch (_) {}
  }
}

final courseRefreshProvider =
    StateNotifierProvider<CourseRefreshNotifier, AsyncValue<List<CourseModel>>>((ref) {
  return CourseRefreshNotifier(ref.read(courseRepositoryProvider));
});
