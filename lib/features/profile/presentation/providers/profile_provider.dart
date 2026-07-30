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

  const ProfileState({
    this.profile,
    this.devices = const [],
    this.isLoading = false,
  });

  ProfileState copyWith({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? devices,
    bool? isLoading,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
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

    state = state.copyWith(isLoading: true);
    final profile = await _repo.getProfile(user.id);
    final devices = await _repo.getDevices(user.id);
    state = ProfileState(profile: profile, devices: devices);
  }

  Future<void> updateProfile({
    String? name,
    String? rollNo,
    String? phone,
  }) async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    await _repo.updateProfile(
      userId: user.id,
      name: name,
      rollNo: rollNo,
      phone: phone,
    );
    await _load();
  }

  void refresh() => _load();
}
