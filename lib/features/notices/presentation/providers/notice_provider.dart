import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:notes_app/core/models/notice_model.dart';
import 'package:notes_app/features/notices/data/notice_repository.dart';

final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  return NoticeRepository(Supabase.instance.client);
});

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

class NoticeState {
  final List<Notice> notices;
  final String appVersion;
  final bool isLoading;

  const NoticeState({
    this.notices = const [],
    this.appVersion = '1.0.0',
    this.isLoading = true,
  });

  NoticeState copyWith({
    List<Notice>? notices,
    String? appVersion,
    bool? isLoading,
  }) {
    return NoticeState(
      notices: notices ?? this.notices,
      appVersion: appVersion ?? this.appVersion,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<Notice> get activeNotices {
    return notices
        .where((n) => n.isActive && n.isApplicableToVersion(appVersion))
        .toList();
  }

  Notice? get urgentNotice {
    final urgent = activeNotices.where((n) => n.isUrgent);
    return urgent.isNotEmpty ? urgent.first : null;
  }

  List<Notice> get infoNotices =>
      activeNotices.where((n) => n.isInfo).toList();

  List<Notice> get updateNotices =>
      activeNotices.where((n) => n.isUpdate).toList();
}

class NoticeNotifier extends StateNotifier<NoticeState> {
  final NoticeRepository _repo;

  NoticeNotifier(this._repo) : super(const NoticeState()) {
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    state = state.copyWith(appVersion: info.version);
    fetchNotices();
  }

  Future<void> fetchNotices() async {
    state = state.copyWith(isLoading: true);
    try {
      final notices = await _repo.fetchActiveNotices();
      state = state.copyWith(notices: notices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final noticeProvider =
    StateNotifierProvider<NoticeNotifier, NoticeState>((ref) {
  return NoticeNotifier(ref.read(noticeRepositoryProvider));
});
