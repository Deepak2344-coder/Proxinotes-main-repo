import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/features/profile/data/profile_repository.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(supabaseClientProvider));
});

class ProfileState {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> devices;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.devices = const [],
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? devices,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider), ref);
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repo;
  final Ref _ref;

  ProfileNotifier(this._repo, this._ref) : super(const ProfileState()) {
    _load();
  }

  Future<void> _load() async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getProfile(user.id).timeout(const Duration(seconds: 5)),
        _repo.getDevices(user.id).timeout(const Duration(seconds: 5)),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final devices = results[1] as List<Map<String, dynamic>>;

      state = ProfileState(profile: profile, devices: devices);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateProfile({
    String? name,
    String? rollNo,
    String? phone,
  }) async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    try {
      await _repo.updateProfile(
        userId: user.id,
        name: name,
        rollNo: rollNo,
        phone: phone,
      );
      await _load();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void refresh() => _load();
}
