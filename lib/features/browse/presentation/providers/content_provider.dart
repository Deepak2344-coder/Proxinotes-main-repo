import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/content_model.dart';
import 'package:notes_app/features/browse/data/content_repository.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.read(supabaseClientProvider));
});

final contentListProvider = FutureProvider<List<ContentModel>>((ref) async {
  return ref.read(contentRepositoryProvider).getAllContent();
});

final subjectsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(contentRepositoryProvider).getSubjects();
});

final contentBySubjectProvider =
    FutureProvider.family<List<ContentModel>, String>((ref, subject) async {
  return ref.read(contentRepositoryProvider).getContentBySubject(subject);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<ContentModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(contentRepositoryProvider).searchContent(query);
});

/// Notifier to manually refresh content list
class ContentRefreshNotifier extends StateNotifier<AsyncValue<List<ContentModel>>> {
  final ContentRepository _repo;

  ContentRefreshNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repo.getAllContent();
      state = AsyncValue.data(items);
    } catch (e) {
      // If we have no data yet, show error
      if (state.value == null) {
        state = AsyncValue.error(e, StackTrace.current);
      }
      // Otherwise keep showing stale data (don't overwrite on refresh failure)
    }
  }

  Future<void> refresh() async {
    try {
      final items = await _repo.getAllContent();
      state = AsyncValue.data(items);
    } catch (_) {
      // Keep current data on refresh failure
    }
  }
}

final contentRefreshProvider =
    StateNotifierProvider<ContentRefreshNotifier, AsyncValue<List<ContentModel>>>((ref) {
  return ContentRefreshNotifier(ref.read(contentRepositoryProvider));
});
