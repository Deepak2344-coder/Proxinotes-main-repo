import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/features/viewer/data/viewer_repository.dart';

final viewerRepositoryProvider = Provider<ViewerRepository>((ref) {
  return ViewerRepository(ApiClient.instance);
});

class PageLoadState {
  final bool isLoading;
  final String? error;

  const PageLoadState({this.isLoading = false, this.error});

  PageLoadState copyWith({bool? isLoading, String? error}) {
    return PageLoadState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final pageLoadProvider =
    StateNotifierProvider<PageLoadNotifier, PageLoadState>((ref) {
  return PageLoadNotifier();
});

class PageLoadNotifier extends StateNotifier<PageLoadState> {
  PageLoadNotifier() : super(const PageLoadState());

  void setLoading(bool v) => state = state.copyWith(isLoading: v);
  void setError(String? e) => state = state.copyWith(error: e);
}

final bookmarkIdsProvider =
    StateNotifierProvider<BookmarkNotifier, Set<String>>((ref) {
  return BookmarkNotifier(ref.read(viewerRepositoryProvider));
});

class BookmarkNotifier extends StateNotifier<Set<String>> {
  final ViewerRepository _repo;

  BookmarkNotifier(this._repo) : super({}) {
    _load();
  }

  Future<void> _load() async {
    final bookmarks = await _repo.getBookmarks();
    state = bookmarks.map((e) => e['contentId']!).toSet();
  }

  Future<void> toggle(String contentId, String subject, int chapter) async {
    if (state.contains(contentId)) {
      await _repo.removeBookmark(contentId);
      state = Set.from(state)..remove(contentId);
    } else {
      await _repo.bookmarkContent(
        contentId: contentId,
        subject: subject,
        chapter: chapter,
      );
      state = Set.from(state)..add(contentId);
    }
  }

  Future<void> remove(String contentId) async {
    await _repo.removeBookmark(contentId);
    state = Set.from(state)..remove(contentId);
  }
}

final bookmarksListProvider = FutureProvider<List<Map<String, String>>>((ref) {
  return ref.read(viewerRepositoryProvider).getBookmarks();
});
